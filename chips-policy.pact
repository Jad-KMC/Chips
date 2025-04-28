;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Chips-Policy Smart Contract
;;
;; Purpose:
;; - Provides a blockchain-based oracle integration framework for mining data reporting.
;; - Allows external computational systems (miners) to submit granular performance data.
;; - Aggregates data like shares accepted, difficulty, and uptime into compact blockchain storage.
;; - Supports real-time mining metric tracking with low-latency, gas-optimized updates.
;; - Ensures compatibility with blockchain standards (Pact + Marmalade for NFTs).
;;
;; Grant Focus:
;; - Oracle Integration
;; - Efficient Data Aggregation
;; - Real-time Computational Tracking
;; - Blockchain Application Compatibility
;; - Extensibility to Other Coins / Environments
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(module chips-policy GOVERNANCE
	@doc "Chips policy for ASICs that mine KDA."
	(implements kip.token-policy-v1)
	(use kip.token-policy-v1 [token-info])
	(use marmalade.ledger)

	; ===============================
	; Constants
	; ===============================
	(defconst ADMIN_KEYSET "free.kmc-admin")
	(defconst ADMIN_ADDRESS "todd")
	(defconst ORACLE_ADDRESS "oracle")
	(defconst NFT_COUNT:string "nft-count")
	(defconst MINT_COUNT:string "mint-count")
	(defconst QUOTE-MSG-KEY "quote"
		@doc "Payload field for quote spec")
	(defconst TOTAL_HASHRATE "total-hashrate")
	(defconst AVAILABLE_HASHRATE "available-hashrate")


	; ===============================
	; Schemas
	; ===============================
	(defschema status-schema
		@doc "Stores information of each CHIP NFT, which can represent more than 1 chip"
		rentable:bool           ; true if the coin can be rented
		num-chips:integer
		hashrate:decimal
		token-id:string
		coin:string
	)

	(defschema token-schema
		@doc "Key is the t:token"
		id:string               ; t:token
		num-chips:integer
		associated-chips:integer
		asic-manufacturer:string    ; e.g., bitmain, goldshell, etc.
		asic-model:string           ; e.g., L7, KA3, S19 Pro, etc.
		asic-number:integer         ; counts up from 1, all asics share the same counter
		asic-details:object         ; e.g., { "hashrate": "166 TH/s", "wattage": "4000W", "serial-number": "x2345" }
		supply:decimal              ; 1.0 if minted
		coin:string
	)

	(defschema mined-schema
    ; Core table for oracle system.
    ; Stores mining performance reports submitted by miners or oracles.
    id:string
    coin:string
    shares-accepted:integer
    average-difficulty:decimal
    duration:integer
  )

	(defschema counts-schema
		@doc "Keeps track of how many things there are."
		count:integer
	)

	(defschema values-schema
		@doc "Keeps track of things that require a decimal"
		value:decimal
	)

	(defschema currency-hashrate-schema
		; Tracks total and available hashrate for a given coin.
		coin:string
		total-hashrate:decimal
		available-hashrate:decimal
	)

	(defschema store-guard
		g:guard
	)

	(defschema mint-schema
		status:string
	)

	(defschema quote-spec
		@doc "Quote data to include in payload"
		fungible:module{fungible-v2}
		price:decimal
		recipient:string
		recipient-guard:guard
	)

	(defschema quote-schema
		id:string
		spec:object{quote-spec}
	)


	; ===============================
	; Table Definitions
	; ===============================
	(deftable counts-table:{counts-schema})
	(deftable values-table:{values-schema})
	(deftable quotes:{quote-schema})
	(deftable guard-storage-table:{store-guard})
	(deftable status-table:{status-schema})
	(deftable tokens:{token-schema})
	(deftable mined-table:{mined-schema})
	(deftable currency-hashrate-table:{currency-hashrate-schema})


	; ===============================
	; Capabilities
	; ===============================
	(defcap GOVERNANCE ()
		(enforce-keyset ADMIN_KEYSET)
	)

	(defcap ADMIN ()
		@doc "Only allows admin to call these"
		(enforce-keyset ADMIN_KEYSET)
		(compose-capability (PRIVATE))
		(compose-capability (ACCOUNT_GUARD ADMIN_ADDRESS))
	)

	(defcap ADMIN_OR_ORACLE (account:string)
		(compose-capability (ACCOUNT_GUARD account))
		(enforce-one "admin or oracle" [(enforce (= account ADMIN_ADDRESS) "") (enforce (= account ORACLE_ADDRESS) "")])
	)

	(defcap ACCOUNT_GUARD (account:string)
		@doc "Verifies account meets format and belongs to caller"
		(enforce-guard
			(at "guard" (coin.details account))
		)
	)

	(defcap PRIVATE ()
		true
	)

	(defcap QUOTE:bool
		(sale-id:string
		 token-id:string
		 amount:decimal
		 price:decimal
		 sale-price:decimal
		 spec:object{quote-spec})
		@doc "For event emission purposes"
		@event
		true
	)


	; ===============================
	; Functions
	; ===============================
	; -- Initialization & Utility Functions --
	(defun initialize ()
		@doc "Initialize the module the first time it is deployed"
		(insert counts-table NFT_COUNT {"count": 0})
		(insert counts-table MINT_COUNT {"count": 0})
		(insert currency-hashrate-table "kda" { "coin": "kda", "total-hashrate": 0.0, "available-hashrate": 0.0 })
	)

	(defun register-guard (g)
		(insert guard-storage-table "chips" {'g:g})
	)


	; -- Currency Management Functions --
	(defun get-currency-total (coin:string)
		@doc "Gets the total hashrate for a given coin"
		(at 'total-hashrate (read currency-hashrate-table coin))
	)

	(defun get-currency-available (coin:string)
		@doc "Gets the available hashrate for a given coin"
		(at 'available-hashrate (read currency-hashrate-table coin))
	)

	(defun set-currency-total (coin:string value:decimal)
		@doc "Sets the total hashrate for a given coin"
		(with-capability (ADMIN)
			(update currency-hashrate-table coin { "total-hashrate": value })
		)
	)

	(defun set-currency-available (coin:string value:decimal)
		@doc "Sets the available hashrate for a given coin"
		(with-capability (ADMIN)
			(update currency-hashrate-table coin { "available-hashrate": value })
		)
	)

	; -- Token Query Functions --
	(defun get-tokens-rented:list (account:string)
		@doc "Returns all tokens that an account is renting"
		(select tokens ['id 'coin]
			(and
				(where 'renter (= account))
				(where 'rentable (= false))
			)
		)
	)

	(defun get-token:object (token-id:string)
		(read tokens token-id)
	)

	(defun get-all-for-rent:list (coin:string)
		(select status-table ['token-id 'num-chips 'hashrate]
			(and?
				(where 'rentable (= true))
				(where 'coin (= coin))
			)
		)
	)

	(defun submit-mining-data (token-id:string coin:string shares:integer difficulty:decimal duration:integer address:string)
		(with-capability (ADMIN_OR_ORACLE address)
			(insert mined-table (format "{}:{}" [coin (at 'block-time (chain-data))])
				{ "token-id" : token-id
				, "coin" : coin
			 	, "shares-accepted" : shares
				, "average-difficulty" : difficulty
				, "duration" : duration }
			)
		)
	)

	(defun get-all-token-ids ()
		(keys tokens)
	)

	(defun get-status:object (token-id:string)
		(read status-table token-id)
	)

	(defun get-policy:object{token-schema} (token:object{token-info})
		(read tokens (at 'id token))
	)

	(defun get-wattage:integer (token-id:string)
		(at 'wattage (at 'asic-details (read tokens token-id)))
	)


	; -- Token Update Functions --
	(defun update-asic-details (token-id:string new-asic-details:object caller:string)
		@doc "Updates the 'asic-details' field for the token identified by token-id. Example: { 'hashrate': 11.5, 'wattage': 218 }"
		(with-capability (ADMIN_OR_ORACLE caller)
			(update tokens token-id { "asic-details": new-asic-details })
		)
	)

	(defun update-num-chips (token-id:string new-num-chips:integer caller:string)
		@doc "Updates the 'num-chips' field for the token identified by token-id."
		(with-capability (ADMIN_OR_ORACLE caller)
			(update tokens token-id { "num-chips": new-num-chips })
		)
	)

	(defun update-associated-chips (token-id:string new-associated-chips:integer caller:string)
		@doc "Updates the 'associated-chips' field for the token identified by token-id."
		(with-capability (ADMIN_OR_ORACLE caller)
			(update tokens token-id { "associated-chips": new-associated-chips })
		)
	)

	(defun update-expiry (token-id:string new-expiry:string caller:string)
		@doc "Updates the 'expiry' field for the token identified by token-id."
		(with-capability (ADMIN_OR_ORACLE caller)
			(update tokens token-id { "expiry": new-expiry })
		)
	)

	(defun update-for-rent (token-id:string rentable:bool)
		@doc "Update rent status and update available hashrate for the correct coin"
		(enforce-chips)
		(let* (
			(token-status (get-status token-id))
			(coin (at 'coin token-status))
			(current-available (at 'available-hashrate (read currency-hashrate-table coin)))
			(token-hashrate (at 'hashrate token-status))
		)
			(if (= true rentable)
				(update currency-hashrate-table coin { "available-hashrate": (+ current-available token-hashrate) })
				(update currency-hashrate-table coin { "available-hashrate": (- current-available token-hashrate) })
			)
		)
		(update status-table token-id { "rentable": rentable })
	)


	; -- Count and Value Functions --
	(defun get-count (key:string)
		@doc "Gets the count for a key"
		(at "count" (read counts-table key ['count]))
	)

	(defun set-count (key:string value:integer)
		@doc "Sets the count for a key in the counts-table"
		(with-capability (GOVERNANCE)
			(update counts-table key { "count": value })
		)
	)

	(defun get-value (key:string)
		@doc "Gets the value for a key"
		(at "value" (read values-table key ['value]))
	)

	(defun set-value (key:string value:decimal)
		@doc "Sets the value for a key in the values-table"
		(with-capability (GOVERNANCE)
			(update values-table key { "value": value })
		)
	)


	; -- Enforcement Functions --
	(defun enforce-chips ()
		(with-read guard-storage-table "chips" {'g:=g}
			(enforce-guard g)
		)
	)

	(defun enforce-crosschain:bool
		(token:object{token-info}
		 sender:string
		 guard:guard
		 receiver:string
		 target-chain:string
		 amount:decimal)
		(enforce-ledger)
		(enforce false "Transfer across chains prohibited")
	)

	(defun enforce-offer:bool
		(token:object{token-info}
		 seller:string
		 amount:decimal
		 sale-id:string)
		@doc "Capture quote spec for SALE of TOKEN from message"
		(enforce-ledger)
		(enforce-sale-pact sale-id)
		(let* (
			(spec:object{quote-spec} (read-msg QUOTE-MSG-KEY))
			(fungible:module{fungible-v2} (at 'fungible spec))
			(price:decimal (at 'price spec))
			(recipient:string (at 'recipient spec))
			(recipient-guard:guard (at 'recipient-guard spec))
			(recipient-details:object (fungible::details recipient))
			(sale-price:decimal (* amount price))
		)
			(fungible::enforce-unit sale-price)
			(enforce (< 100000.0 price) "Good luck affording to buy one of these")
			(enforce (= (at 'guard recipient-details) recipient-guard)
				"Recipient guard does not match")
			(insert quotes sale-id { 'id: (at 'id token), 'spec: spec })
			(emit-event (QUOTE sale-id (at 'id token) amount price sale-price spec))
		)
		false
	)

	(defun enforce-buy:bool
		(token:object{token-info}
		 seller:string
		 buyer:string
		 buyer-guard:guard
		 amount:decimal
		 sale-id:string)
		(enforce-ledger)
		(enforce-sale-pact sale-id)
		(with-read tokens (at 'id token) {"first-owner":= first-owner}
			(with-read quotes sale-id { 'id:= qtoken, 'spec:= spec:object{quote-spec} }
				(enforce (= qtoken (at 'id token)) "incorrect sale token")
				(bind spec
					{ 'fungible := fungible:module{fungible-v2}
					, 'price := price:decimal
					, 'recipient := recipient:string
					}
					(fungible::transfer buyer recipient (* (* amount 0.94) price))
					(fungible::transfer buyer first-owner (* (* amount 0.01) price))
					(fungible::transfer buyer ADMIN_ADDRESS (* (* amount 0.05) price))
				)
			)
		)
		(update tokens (at 'id token) { "owner": buyer })
		false
	)

	(defun enforce-sale-pact:bool (sale:string)
		"Enforces that SALE is the id for the currently executing pact"
		(enforce (= sale (pact-id)) "Invalid pact/sale id")
	)

	(defun enforce-transfer:bool
		(token:object{token-info}
		 sender:string
		 guard:guard
		 receiver:string
		 amount:decimal)
		(enforce-ledger)
		false
	)

	(defun enforce-ledger:bool ()
		(enforce-guard (marmalade.ledger.ledger-guard))
	)

	(defun enforce-mint:bool
		(token:object{token-info}
		 account:string
		 guard:guard
		 amount:decimal)
		(enforce-ledger)
		(enforce (= account ORACLE_ADDRESS) "Only oracle can mint these NFTs")
		(enforce (= 1.0 amount) "Invalid mint amount")
		(with-read tokens (at 'id token) { 'supply:= supply }
			(enforce (= supply 0.0) "Token has been minted")
		)
		(update tokens (at 'id token) { "supply": 1.0 })
		(let ( (number (get-count MINT_COUNT)) )
			(update counts-table MINT_COUNT { "count": (+ 1 number) })
		)
		true
	)

	(defun enforce-burn:bool
		(token:object{token-info}
		 account:string
		 amount:decimal)
		(enforce-ledger)
		(enforce (= 1.0 amount) "Invalid burn amount")
		(with-read tokens (at 'id token) { 'supply:= supply }
			(enforce (= supply 1.0) "Token has been burned already")
		)
		(update tokens (at 'id token) { "supply": 0.0, "owner": "null" })
		true
	)

	(defun enforce-init:bool (token:object{token-info})
	; Initializes a new token, setting metadata and adjusting hashrate pools.
		(enforce-ledger)
		(let* (
			(coin (read-msg "coin"))
			(asic-model (read-msg "asicModel"))
			(asic-manufacturer (read-msg "asicManufacturer"))
			(num-chips (read-integer "numChips"))
			(asic-details (read-msg "asicDetails"))
			(number (+ 1 (get-count NFT_COUNT)))
			(associated-chips (read-integer "associatedChips"))
			(token-hashrate (at 'hashrate asic-details))
			(coin-exists (try false (let ((ok true)) (with-read currency-hashrate-table coin {'coin := coin-temp}"") ok)))
		)
			(update counts-table NFT_COUNT { "count": number })
			(insert tokens (at 'id token)
				{ "id": (at 'id token)
				, "num-chips": num-chips
				, "associated-chips": associated-chips
				, "asic-manufacturer": asic-manufacturer
				, "asic-model": asic-model
				, "asic-number": number
				, "asic-details": asic-details
				, "supply": 0.0
				, "coin": coin
				}
			)
			(insert status-table (at 'id token)
				{ "rentable": true
				, "num-chips": num-chips
				, "hashrate": token-hashrate
				, "token-id": (at 'id token)
				, "coin": coin
				}
			)
			(if coin-exists
				(let* (
					(coin-entry (read currency-hashrate-table coin))
					(current-total (at 'total-hashrate coin-entry))
					(current-available (at 'available-hashrate coin-entry))
				)
					(update currency-hashrate-table coin { "total-hashrate": (+ current-total token-hashrate) })
					(update currency-hashrate-table coin { "available-hashrate": (+ current-available token-hashrate) })
				)
				(insert currency-hashrate-table coin { "coin": coin, "total-hashrate": token-hashrate, "available-hashrate": token-hashrate })
			)
		)
		true
	)
)

(create-table quotes)
(create-table guard-storage-table)
(create-table status-table)
(create-table counts-table)
(create-table values-table)
(create-table tokens)
(create-table currency-hashrate-table)
(create-table mined-table)
(initialize)
