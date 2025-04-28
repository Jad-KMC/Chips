(module chips-presale GOVERNANCE
  (use fungible-v2)
  (use coin)
  (use n_e98a056e3e14203e6ec18fada427334b21b667d8.chips-oracle)

  (defconst SITE_ORACLE_ADDRESS "k:5ca6584249185f9b9aeda28acd9da5316273d6c51e89062d8bb815b2b3c0eb8e")
  (defconst BRIDGE_ORACLE_ADDRESS "k:4aab9f08f1bd86c3ce007a9a87225ef061c09e7062efa622e2fd704c24514cfa")
  (defconst ADMIN_ADDRESS "k:35fe76ea8f40caa2bb660b3236132f339dfdac2586a3d2a9d63ea96ee91202ad")
  (defconst TEK "k:37f8a1e52744b6d07663b071f2f2d73c8fe549e81b7e1bb6ff8d4c38d323f98c")
  (defconst ADMIN_KEYSET "n_e98a056e3e14203e6ec18fada427334b21b667d8.chips-admin")
  (defconst ORDERS_COUNT "orders-count") ; # of pre-orders
  (defconst BRIDGE_COUNT "bridge-count")
  (defconst CHIPS_PRESALE_BANK "chips-presale-bank")
  (defconst TOTALS "totals")
  (defconst BTC_MINED_UPDATE_COUNT "btc-mined-update-count")
  (defconst TOTAL_BTC_HASHRATE "total-btc-hashrate")
  (defconst BTC_HASHRATE_POOL "btc-hashrate-pool")
  (defconst GONZO_ADDRESS "k:a57e1b88758865333f88630026c9f59f87c5a924764eaafc3908e30455516a1e") 
  
  (defschema counts-schema
    count:integer
  )

  (defschema price-schema
    value:decimal
  )

  (defschema mineable-coins-schema
    ; key is the coin that we will be mining. "cKDA" "cBTC" "cLTC" "cKAS"...
    fungible:module{fungible-v2}
  )

  (defschema expected-rewards-schema
    @doc "Stores information for how much each cToken will reward the user in a 1 month period"
    ; cType is the key
    rewards:decimal
  )

  (defschema bridge-tx-schema
    @doc "Stores information about bridged transactions"
    unique-id:string
    eth-address:string
    kAddress:string
    cType:string
    amount:decimal
    bridged:bool
  )

  (defschema james-schema
    @doc "added for accounting purposes"
    account:string
    kda-price:decimal
    cType:string
    cTokens-sold:decimal
    cTokens-usd-price:decimal
    date:time
  )

  (defschema live-hashrate-schema
    @doc "Stores information on live-hashrate purchases"
    ;key is the account that ordered the hashrate
    ;previously-mined gets updated whenever they buy more hashrate, or the total hashrate pool increases
    account:string
    mined-count:integer
    cTokens-sold:decimal
    previously-mined:decimal
  )

  (defschema mined-schema
    @doc "Tracks the total amount of coins mined by the live-hashrate feature"
    ; key is the mined coin "btc" and the update-count for that coin. ex. btc:1
    total-mined:decimal
  )

  (defschema sold-schema
    @doc "Stores info on how much of each token-type is sold"
    ; "cKDA" "cBTC" "cLTC" "cKAS" "kWatt" "outside" "total"
    amount:decimal
  )

  (defschema electric-schema
    @doc "Tracks electric proportions across allocations"
    ; key is gonzo account
    seconds-accountable:decimal
    last-purchase-time:time
  )

  (defschema sold-history-schema
    @doc "Stores info on how much of each token-type is sold"
    ; "cKDA" "cBTC" "cLTC" "cKAS" "kWatt" "outside"
    amount:decimal
    dollar-value:decimal
  )

  (defschema promotion-schema 
    @doc "Stores info of peoples free kWATTs"
    account:string
    amount:decimal
    purchased:bool
    referrals:integer
  )

  (defschema kmc-discount-schema
    num-nfts:decimal
  )

  (defschema store-guard
    g:guard
  )

  (defschema discount-schema
    @doc "Stores info on total kWATT discounts available to a k:address"
    applied-discount:decimal
    roles:[string]
  )

  (defschema role-schema
    @doc "Stores info on what each discord role is worth in terms of discounts"
    role:string
    discount-value:decimal
  )

  (deftable discount-table:{discount-schema}) ;create
  (deftable role-table:{role-schema}) ;create
  (deftable counts-table:{counts-schema})
  (deftable price-table:{price-schema})
  (deftable sold-table:{sold-schema})
  (deftable sold-history-table:{sold-history-schema})
  (deftable mineable-coins-table:{mineable-coins-schema})
  (deftable bridge-tx-table:{bridge-tx-schema})
  (deftable expected-rewards-table:{expected-rewards-schema})
  (deftable james-table:{james-schema})
  (deftable promotion-table:{promotion-schema})
  (deftable mined-table:{mined-schema})
  (deftable live-hashrate-table:{live-hashrate-schema})
  (deftable electric-table:{electric-schema})
  (deftable guard-storage-table:{store-guard})
  (deftable kmc-discount-table:{kmc-discount-schema})

  (defun initialize ()
    (with-capability (GOVERNANCE)
        (add-or-update-role "OG" 0.01 ADMIN_ADDRESS)
        (add-or-update-role "Community Support" 0.02 ADMIN_ADDRESS)
        (add-or-update-role "Chip Off the Old Block" 0.015 ADMIN_ADDRESS)
        (add-or-update-role "Brand Ambassador" 0.03 ADMIN_ADDRESS)
        (add-or-update-role "Investor" 0.035 ADMIN_ADDRESS)
        (add-or-update-role "Partner" 0.02 ADMIN_ADDRESS)
        (add-or-update-role "Chip" 0.00 ADMIN_ADDRESS)
        (add-or-update-role "Hashboard" 0.00 ADMIN_ADDRESS)
        (add-or-update-role "Control Board" 0.00 ADMIN_ADDRESS)
        (add-or-update-role "Box Miner" 0.00 ADMIN_ADDRESS)
        (add-or-update-role "ASIC" 0.00 ADMIN_ADDRESS)
        (add-or-update-role "Home Farm" 0.01 ADMIN_ADDRESS)
        (add-or-update-role "Full Rack" 0.02 ADMIN_ADDRESS)
        (add-or-update-role "Mining Farm" 0.05 ADMIN_ADDRESS)
        (add-or-update-role "Data Center" 0.10 ADMIN_ADDRESS)
    )
  )
 
  (defun insert-coin-mined (coin:string amount:decimal)
    @doc "Allows the oracle to submit an updated total of the BTC mined."
    (with-capability (ADMIN)
      (increase-count BTC_MINED_UPDATE_COUNT)
      (let*
          (
            (current-mined-count (get-count BTC_MINED_UPDATE_COUNT))
            (current-mined-amount (get-mined-for-count "BTC" (- current-mined-count 1)))
          )
          (enforce (<= current-mined-amount amount ) "Insert failed, amount must be equal to or higher than previous")
          (insert mined-table (format "{}:{}" [coin current-mined-count])
            { "total-mined" : amount }
          )
      )
    )
  )

  (defun combine-both-bridges (kAddress:string cType:string amount:decimal unique-id:string eth-address:string caller:string referrer:string)
    (with-capability (ADMIN_OR_BRIDGE caller)
      (add-bridge-data kAddress cType amount unique-id eth-address caller)
      (bridge-pre-order unique-id kAddress caller referrer)
      (if (= "icBTC" cType)
        (let*
            (
              (remaining-hashrate (get-remaining-instant-hashrate cType))
            )
            (enforce (>= remaining-hashrate 0.0) (format "Error: You are trying to buy {} too much TH/s, please adjust your purchase amount down." [(- 0 remaining-hashrate)]))
        )
        ""
      )
      (format "Bridged {} {} tokens to {} with id {}" [amount cType kAddress unique-id])
    )
  )

  (defun order-live-hashrate (account:string cType:string amount:decimal referrer:string)
    @doc "Order hashrate and instantly start earning rewards"
    (enforce (= cType "icBTC") "You can only purchase instant hashrate through this function")
    (with-capability (PRIVATE)
        (pre-order-work account cType (round amount 6) referrer))
    (let*
        (
          (remaining-hashrate (get-remaining-instant-hashrate cType))
          (cToken-minus-electric (get-instant-price cType))
          (kda-price (chips-oracle.get-current-price "KDA"))
          (kda-amount-per-cToken (/ cToken-minus-electric kda-price))
          (total-kda-required (round (* amount kda-amount-per-cToken) 6))
          (dollar-value (* total-kda-required kda-price))
        )
        (enforce (>= remaining-hashrate 0.0) (format "Error: You are trying to buy {} too much TH/s, please adjust your purchase amount down." [(- 0 remaining-hashrate)]))
        (coin.transfer account CHIPS_PRESALE_BANK total-kda-required)
        (format "Successfully purchased ${} worth of instant BTC hashrate! Go to the Claim Rewards tab to see your hashrate statistics." [dollar-value])
    )
  )

  (defun pre-order (account:string cType:string amount:decimal referrer:string)
    @doc "Allows a user to pre-order any type of cToken"
    (with-capability (PRIVATE)
        (pre-order-work account cType (round amount 6) referrer))
    (let*
        (
          (cToken-price-usd (chips-oracle.get-current-price cType))
          (kda-price (chips-oracle.get-current-price "KDA"))
          (kda-amount-per-cToken (/ cToken-price-usd kda-price))
          (total-kda-required (round (* amount kda-amount-per-cToken) 6))
          (dollar-value (* amount cToken-price-usd))
        )
        ; (with-capability (PRIVATE) 
        ;     (add-promo account amount cType))
        (coin.transfer account CHIPS_PRESALE_BANK total-kda-required)
        (format "Purchased {} {} tokens for {} kda. {} USD equivalent" [amount cType total-kda-required dollar-value])
    )
  )

  (defun get-kmc-nft-count (account:string)
    (with-default-read kmc-discount-table account
      { "num-nfts" : 0.0 }
      { "num-nfts" := num-nfts }
      num-nfts
    )
  )

  (defun set-kmc-nft-count (account:string nft-count:decimal caller:string)
    (with-capability (ADMIN_OR_BRIDGE caller)
      (write kmc-discount-table account
        { "num-nfts" : nft-count })
    )
  )

  (defun add-or-update-role (role:string discount-value:decimal caller:string)
    (with-capability (ADMIN_OR_BRIDGE caller)
      (write role-table role
        { "role" : role
        , "discount-value" : discount-value})
    )
  )

  (defun get-role-info (role:string)
    (read role-table role)
  )

  (defun get-user-discount-info (kAddress:string)
    (with-default-read discount-table kAddress
      { "applied-discount" : 0.0
      , "roles" : []}
      { "applied-discount" := applied-discount
      , "roles" := roles}
      { "applied-discount" : applied-discount, "roles" : roles }
    )
  )

  (defun get-user-applied-discount (kAddress:string)
    (with-default-read discount-table kAddress
      { "applied-discount" : 0.0}
      { "applied-discount" := applied-discount}
      applied-discount
    )
  )

  (defun update-user-discounts (kAddress:string roles:[string] caller:string)
    @doc "Updates the kWATT discount a user is entitled to based on their discord roles"
    (with-capability (ADMIN_OR_TEK caller)
      (let*
        (
          (role-discount-amounts (map (get-role-info) roles))
          (total-discount (fold (+) 0.0 (map (at 'discount-value) role-discount-amounts)))
        )
        (write discount-table kAddress
          { "applied-discount" : total-discount
          , "roles" : roles })
        (format "Roles totalling a discount of {}% have been updated to: {}" [(* 100 total-discount) roles])
      )
    )
  )

  (defun poll-balances (account:string)
    (fold (+) 0.0  (zip (*) (+ (map (poll-balance account) ["cKDA" "cLTC" "cBTC" "cKAS" "cALPH"]) [(at 'cTokens-sold (get-live-hashrate-data account))] )
    (map (chips-oracle.get-current-price) ["cKDA" "cLTC" "cBTC" "cKAS" "cALPH" "icBTC"]) ))
  )

  (defun poll-balance (account:string cType:string)
    (let*
      (
        (fung:module{fungible-v2} (at 'fungible (read mineable-coins-table cType)))
        (exists (try false (let ((ok true)) (fung::get-balance account)"" ok)))
      )
      (if (= exists true)
        (fung::get-balance account)
        0.0)
    )
  )

  (defun update-referral (account:string dollar-value:decimal referrer:bool)
    (require-capability (PRIVATE))
    (with-default-read promotion-table account
      { "amount" : 0.0
      , "purchased" : false
      , "referrals" : 0 }
      { "amount" := kWatt-amount
      , "purchased" := purchased
      , "referrals" := referrals }
      (if (= referrer true)
        [(write promotion-table account ; 1.5% for the referrer
          { "account" : account
          , "amount" : (+ kWatt-amount (round (* dollar-value 0.0012) 8)) ; 0.015*0.08 = 0.0012
          , "purchased" : purchased
          , "referrals" : (+ 1 referrals) }) (emit-event (REFERRAL_LOGGED account (round (* dollar-value 0.0012) 8)))]
        (if (= purchased false)
          [(write promotion-table account ;2.5% for the referral but only on their first purchase
            { "account" : account
            , "amount" : (+ kWatt-amount (round (* dollar-value 0.002) 8)) ; 0.025*0.08 = 0.002
            , "purchased" : true
            , "referrals" : referrals }) (emit-event (REFERRAL_LOGGED account (round (* dollar-value 0.002) 8)))]
            ""
        )
      )
    )
  )

  (defun add-promo (account:string cToken-amount:decimal cType:string)
    @doc "Adds kWATT tracking information for a later airdrop"
    (require-capability (PRIVATE))
    (with-default-read promotion-table account
      { "amount" : 0.0 }
      { "amount":= kWatt-amount }
    ;   (defun calculate-kWatts-required (num-cTokens:decimal cType:string)
      (if (= 0.0 kWatt-amount)
        (insert promotion-table account
          { "account" : account
          , "amount" : (round (* (calculate-kWatts-required cToken-amount cType) 0.46667) 6) })
        (update promotion-table account
          { "amount" : (+ kWatt-amount (round (* (calculate-kWatts-required cToken-amount cType) 0.46667) 6)) })
      )
    )
  )

  (defun add-bridge-data (kAddress:string cType:string amount:decimal unique-id:string eth-address:string caller:string)
    (with-capability (ADMIN_OR_BRIDGE caller)
      (with-default-read bridge-tx-table unique-id
            { "kAddress": "none" }
            { "kAddress" := kAddress }
            (if (= "none" kAddress)
                (with-capability (PRIVATE)
                    (insert bridge-tx-table unique-id
                        { "unique-id" : unique-id
                        , "eth-address" : eth-address
                        , "kAddress" : kAddress
                        , "cType" : cType
                        , "amount" : (round amount 6)
                        , "bridged" : false })
                    (increase-count BRIDGE_COUNT))
                (update bridge-tx-table unique-id
                    { "eth-address" : eth-address
                    , "cType" : cType
                    , "amount" : (round amount 6)})
            )
        )
      (format "Data for id {} added. Amount: {}, kAddress: {}, cType: {}, eth-address: {}" [unique-id (round amount 6) kAddress cType eth-address])
    )
  )

  (defun add-kAddress (unique-id:string kAddress:string)
    (with-capability (SITE_ORACLE SITE_ORACLE_ADDRESS)
      (with-default-read bridge-tx-table unique-id
          { "unique-id": unique-id
          , "eth-address" : "none"
          , "kAddress" : "unconnected"
          , "cType" : "none"
          , "amount" : 0.0
          , "bridged" : false }
          { "unique-id":= unique-id
          , "eth-address" := eth-address
          , "kAddress" := kAddress2
          , "cType" := cType
          , "amount" := amount
          , "bridged":= bridged  }
          (enforce (= "unconnected" kAddress2) "kAddress already added")
          (write bridge-tx-table unique-id
              { "unique-id" : unique-id
              , "eth-address" : eth-address
              , "kAddress" : kAddress
              , "cType" : cType
              , "amount" : amount
              , "bridged": bridged  }))

    )
  )

  (defun get-user-referrals (account:string)
    @doc "Shows how many kWATTs an account has earned through promos or referrals"
    (read promotion-table account)
  )

  (defun fix-bridge (bridged:bool unique-id:string)
    (with-capability (ADMIN)
      (update bridge-tx-table unique-id { "bridged" : false })
    )
  )

  (defun bridge-pre-order (unique-id:string input-kAddress:string caller:string referrer:string)
    (with-capability (ADMIN_OR_BRIDGE caller)
      (let* (
          (bridge-info (read bridge-tx-table unique-id))
          (contract-kAddress (at 'kAddress bridge-info))
          (kAddress (if (= "none" contract-kAddress) input-kAddress contract-kAddress))
          (eth-address (at 'eth-address bridge-info))
          (cType (at 'cType bridge-info))
          (amount (at 'amount bridge-info))
          (bridged (at 'bridged bridge-info))
        )
        (enforce (!= kAddress "unconnected") "kAddress has not been added to the bridge table yet")
        (enforce (!= kAddress "none") "kAddress needs to be added still")
        (enforce (!= true bridged) "Transaction has already been bridged")
        (update bridge-tx-table unique-id
          { "bridged" : true })
        (with-capability (PRIVATE)
            (pre-order-work kAddress cType amount referrer))
        (format "Bridged {} {} tokens to {} with id {}" [amount cType kAddress unique-id])
        )
    )
  )

  (defun pre-order-work (account:string cType:string amount:decimal referrer:string)
    (require-capability (PRIVATE))
    (enforce (contains cType ["cKDA" "cLTC" "cBTC" "cKAS" "icBTC" "cALPH"]) (format "{}: This type of cToken is not supported" [cType]))
    (enforce (> amount 0.0) "cToken amount must be positive")
    (let*
        (
          (orders-count-string (int-to-str 10 (get-count ORDERS_COUNT)))
          (cToken-price (chips-oracle.get-current-price cType))
          (previous-data (read sold-history-table cType))
          (dollar-value (* cToken-price amount))
          (fung:module{fungible-v2} (at 'fungible (read mineable-coins-table cType)))
        )
        (if (or (= "none" referrer) (= account referrer))
          ""
          (with-capability (PRIVATE)
            (update-referral account dollar-value false)
            (update-referral referrer dollar-value true) )
        )
        (insert james-table orders-count-string
          { "account" : account
          , "kda-price" : (chips-oracle.get-current-price "KDA")
          , "cTokens-sold" : amount
          , "cType" : cType
          , "cTokens-usd-price" : cToken-price
          , "date" : (at 'block-time (chain-data)) })
        (update sold-history-table cType
          { "amount" : (+ (at 'amount previous-data) amount)
          , "dollar-value" : (+ (at 'dollar-value previous-data) (* amount cToken-price))})
        (if (!= cType "icBTC")
            (with-capability (BANK_DEBIT)
              (install-capability (fung::TRANSFER CHIPS_PRESALE_BANK account amount))
              (fung::transfer-create CHIPS_PRESALE_BANK account (read-keyset 'ks) amount)
            )
            (with-capability (PRIVATE)
              (update-user-live-hashrate account amount)
              (update-user-live-hashrate GONZO_ADDRESS (- 0 amount))
              (update-electric-tracker)
            )
        )
        (with-capability (PRIVATE)
          (increase-count ORDERS_COUNT))
    )
  )

  (defun update-electric-tracker ()
    (require-capability (PRIVATE))
    (let*
        (
          (total-hashrate (get-presale-price TOTAL_BTC_HASHRATE))
          (gonzo-hashrate (at 'cTokens-sold (get-live-hashrate-data GONZO_ADDRESS)))
          (percent-owned (/ gonzo-hashrate total-hashrate))
          (current-time (at 'block-time (chain-data)))
          (current-electric-data (read electric-table GONZO_ADDRESS))
          (last-purchase-time (at 'last-purchase-time current-electric-data))
          (seconds-between (diff-time current-time last-purchase-time))
          (new-responsibility (* percent-owned seconds-between))
          (full-addition (+ new-responsibility (at 'seconds-accountable current-electric-data)))
        )
        (update electric-table GONZO_ADDRESS
          { "seconds-accountable" : (round full-addition 1)
          , "last-purchase-time" : current-time }
        )
    )
  )

  (defun get-responsibility (until:time)
    @doc "Returns % of bill owed from the start of the tracking until a specific moment in time"
    (let*
        (
          (total-hashrate (get-presale-price TOTAL_BTC_HASHRATE))
          (gonzo-hashrate (at 'cTokens-sold (get-live-hashrate-data GONZO_ADDRESS)))
          (percent-owned (/ gonzo-hashrate total-hashrate))
          (current-electric-data (read electric-table GONZO_ADDRESS))
          (last-purchase-time (at 'last-purchase-time current-electric-data))
          (seconds-between (diff-time until last-purchase-time))
          (new-responsibility (* percent-owned seconds-between))
          (total-responsibility (round (+ new-responsibility (at 'seconds-accountable current-electric-data)) 3))
          (start-time (time "2025-01-02T09:00:00Z"))
          (diff-between-start-and-until (diff-time until start-time))
          (percent-owed (/ total-responsibility diff-between-start-and-until))
        )
        (round percent-owed 6)
    )
  )

  (defun update-user-live-hashrate (account:string amount:decimal)
    (require-capability (PRIVATE))
    (with-default-read live-hashrate-table account
        { "cTokens-sold" : -0.000000001
        , "previously-mined" : 0.0 }
        { "cTokens-sold" := old-cTokens-amount
        , "previously-mined" := previously-mined }
        (if (< old-cTokens-amount 0.0)
            (insert live-hashrate-table account
              { "account" : account
              , "mined-count" : (get-count BTC_MINED_UPDATE_COUNT)
              , "cTokens-sold": amount
              , "previously-mined" : 0.0})
            [(update live-hashrate-table account
              { "mined-count" : (get-count BTC_MINED_UPDATE_COUNT)
              , "cTokens-sold" : (+ old-cTokens-amount amount)
              , "previously-mined" : (+ previously-mined (get-mined-for-user account)) }
            ) "Updated"]
        )
    )
  )

  (defun get-mined-for-user (account:string)
    (let*
        (
          (live-hashrate-data (get-live-hashrate-data account))
          (user-hashrate (at 'cTokens-sold live-hashrate-data))
          (previous-mined-count (at 'mined-count live-hashrate-data))
          (current-mined-count (get-count BTC_MINED_UPDATE_COUNT))
          (previous-mined-amount (get-mined-for-count "BTC" previous-mined-count))
          (current-mined-amount (get-mined-for-count "BTC" current-mined-count))
          (mined-while-live (- current-mined-amount previous-mined-amount))
          (total-hashrate (get-presale-price TOTAL_BTC_HASHRATE))
          (user-percentage-of-hashrate (/ user-hashrate total-hashrate))
        )
        (round (* user-percentage-of-hashrate mined-while-live) 18)
    )
  )

  (defun get-total-user-mined (account:string)
    (let*
        (
          (instant-mined (get-mined-for-user account))
          (previously-mined (at 'previously-mined (read live-hashrate-table account)))
        )
        (+ instant-mined previously-mined)
    )
  )

  (defun get-mined-for-count (type:string count:integer)
    (at 'total-mined (read mined-table (format "{}:{}" [type count])))
  )

  (defun get-total-mined (type:string)
    (at 'total-mined (read mined-table (format "{}:{}" [type (get-count BTC_MINED_UPDATE_COUNT)])))
  )

  (defun set-coin-mined-at-count (coin:string amount:decimal count:integer)
    (with-capability (ADMIN)
      (update mined-table (format "{}:{}" [coin count])
        { "total-mined" : amount })
    )
  )

  (defun update-multiple-before-total (users:list)
    @doc "Mapping over a list of users"
    (with-capability (ADMIN)
      (map (update-mined-before-total) users)
    )
  )

  (defun update-mined-before-total (user:string)
    @doc "Updates user live hashrate without restriction, for use before updating the total live hashrate"
    (with-capability (ADMIN)
      (update-user-live-hashrate user 0.0)
    )
  )

  (defun update-total-btc-hashrate (new-amount:decimal existing:decimal hashrate-owner:string)
    @doc "Does all the necessary work to update the total hashrate"
    (with-capability (PRIVATE)
      (update-user-live-hashrate hashrate-owner new-amount))
    (with-capability (ADMIN)
      (set-price TOTAL_BTC_HASHRATE (+ new-amount existing))
    )
    ; Every user needs to have their "previously-mined" calculated and submitted before calling this
    ; function "live-hashrate-keys" and "update-multiple-before-total" can be used in conjunction.
  )

  (defun get-remaining-instant-hashrate (coin:string) ;coin is icBTC until more are added
    (let*
        (
          (already-sold (at 'amount (at 1 (get-presale-stat coin))))
          (total (get-presale-price "total-btc-hashrate"))
        )
        (- total already-sold)
    )
  )

  (defun get-remaining-seconds ()
    (let*
        (
          (start-date (time "2025-01-01T09:00:00Z"))
          (end-date (add-time start-date (days 120)))
          (current-date (at 'block-time (chain-data)))
        )
        (diff-time end-date current-date)
    )
  )

  (defun get-instant-price (cType:string)
    @doc "Returns the price of instant hashrate, accounting for electricity remaining"
    (let*
        (
          (remaining-seconds (get-remaining-seconds))
          (percent-seconds-remaining (round (/ remaining-seconds 10368000.0) 4))
          (electricity-cost (round (* 5.17 percent-seconds-remaining) 4))
          (cToken-price-usd (chips-oracle.get-current-price cType))
          (cToken-minus-electric (- cToken-price-usd (- 5.17 electricity-cost)))
        )
        cToken-minus-electric
    )
  )

  (defun live-hashrate-keys ()
    (keys live-hashrate-table)
  )

  (defun get-live-hashrate-data (account:string)
    (read live-hashrate-table account)
  )

  (defun get-order (order-count:string)
    (read james-table order-count)
  )

  (defun get-all-sales-data ()
    (select james-table (where "cType" (!= "none")))
  )

  (defun get-sales-data-for-cType (cType:string)
    (select james-table (where "cType" (= cType)))
  )

  (defun get-all-bridge-info ()
    (select bridge-tx-table (where "unique-id" (!= "0")))
  )

  (defun get-user-bridge-info (eth-address:string)
    (select bridge-tx-table (where "eth-address" (= eth-address)))
  )

  (defun get-bridge-info-from-id (unique-id:string)
    (read bridge-tx-table unique-id)
  )

  (defun get-user-orders (address:string)
    @doc "returns a list of all user orders"
    (select james-table (where "account" (= address)))
  )

  (defun get-presale-stat (cType:string)
    @doc "returns the stats of a single cType"
    [ (format "{}" [cType]), (read sold-history-table cType)]
  )

  (defun get-all-presale-stats ()
    (map (get-presale-stat) ["cKDA" "cBTC" "cLTC" "cKAS" "cALPH" "icBTC" "kWATT" "outside"])
  )

  (defun calculate-kWatts-required (num-cTokens:decimal cType:string)
    @doc "Calculates the kWatts required for an amount of cToknes to run for 1 month, assuming no discounts"
    (let* (
            (cBTC-kwatt-monthly 13.5)
            (cKDA-kwatt-monthly 13.7)
            (cLTC-kwatt-monthly 15.2)
            (cKAS-kwatt-monthly 10.8)
            (cALPH-kwatt-monthly 22.4)
            (chosen-cType-kwatt (if (= cType "cBTC") cBTC-kwatt-monthly (if (= cType "cKDA") cKDA-kwatt-monthly (if (= cType "cLTC") cLTC-kwatt-monthly (if (= cType "cKAS") cKAS-kwatt-monthly 0)))))
            (chosen2 (if (= cType "cALPH") cALPH-kwatt-monthly chosen-cType-kwatt))
        )
            (* chosen2 num-cTokens)
        )
  )

  (defun calculate-power-output (num-cTokens:decimal cType:string)
    (let* (
            (cBTC-power-x 1.0)
            (cKDA-power-x 1.0)
            (cLTC-power-x 0.1)
            (cKAS-power-x 0.1)
            (cALPH-power-x 0.1)
            (chosen-cType-power (if (= cType "cBTC") cBTC-power-x (if (= cType "cKDA") cKDA-power-x (if (= cType "cLTC") cLTC-power-x (if (= cType "cKAS") cKAS-power-x 0)))))
            (chosen2 (if (= cType "cALPH") cALPH-power-x chosen-cType-power))
        )
        (* chosen2 num-cTokens)
    )
  )

  (defun get-kwatts-and-power (num-cTokens:decimal cType:string)
    (let (
            (token2 (if (= "cLTC" cType) (at 'rewards (read expected-rewards-table "cLTC2")) 0.0))
        )
        { "power" : (round (calculate-power-output num-cTokens cType) 3), "kWatts" : (* (round (calculate-kWatts-required num-cTokens cType) 2) 0.08)
        , "rewards" : { "token1" : (* (at 'rewards (read expected-rewards-table cType)) num-cTokens), "token2" : (* num-cTokens token2) }}
    )
  )

  (defun set-expected-rewards (cType:string reward1:decimal reward2:decimal)
    (with-capability (ADMIN)
        (update expected-rewards-table cType { "rewards" : reward1 })
        (if (= "cLTC" cType) (update expected-rewards-table "cLTC2" { "rewards" : reward2 }) "")
    )
  )

  (defun increase-count (key:string)
    ;increase the count of a key in a table by 1
    (require-capability (PRIVATE))
    (update counts-table key {"count": (+ 1 (get-count key))})
  )

  (defun get-count (key:string)
    @doc "Gets the count for a key"
    (at "count" (read counts-table key ['count]))
  )

  (defun set-count (key:string amount:integer)
    (update counts-table key
      { "count" : amount })
  )

  (defun get-presale-price (key:string)
    @doc "Returns values from the price-table on this contract"
    (at 'value (read price-table key))
  )

  (defun get-price (cType:string)
    (chips-oracle.get-current-price cType)
  )

  (defun get-price-history (cType:string)
    (chips-oracle.get-price-history cType)
  )

  (defun set-price (cType:string price:decimal )
    (with-capability (ADMIN)
      (update price-table cType
        { "value" : price })
    )
  )

;   (defun send-kWatt (sender:string receiver:string amount:decimal)
;     (kWatt.transfer-create sender receiver (read-keyset 'ks) amount)
;     (format "Sent {} kWatt to {}" [amount receiver])
;   )

  (defun send-coin (sender:string receiver:string amount:decimal)
    (coin.transfer-create sender receiver (read-keyset 'chips-bank) amount)
    (format "Sent {} kda to {}" [amount receiver])
  )

  (defun withdraw-contract-funds (account:string)
	(with-capability (ACCOUNT_GUARD ADMIN_ADDRESS)
	(with-capability (BANK_DEBIT)
		(coin.transfer account ADMIN_ADDRESS (coin.get-balance account))
	))
  )

  (defun register-guard (g)
    (insert guard-storage-table "chips" {'g:g})
  )

  (defun enforce-chips ()
    (with-read guard-storage-table "chips" {'g:=g}
      (enforce-guard g)
    )
  )
  ;; Capability user guard: capability predicate function
  (defun require-BANK_DEBIT ()
    (require-capability (BANK_DEBIT))
  )

  ;; create an account with the BANK DEBIT capability
  (defun create-BANK_DEBIT-guard ()
    (create-user-guard (require-BANK_DEBIT))
  )

  (defcap BANK_DEBIT () true)

  (defcap REFERRAL_LOGGED (account:string amount:decimal)
    @event
    true
  )

  (defcap ADMIN_OR_BRIDGE (account:string)
    (compose-capability (ACCOUNT_GUARD account))
    (compose-capability (PRIVATE))
    (enforce-one "admin or discord" [(enforce (= account ADMIN_ADDRESS) "") (enforce (= account BRIDGE_ORACLE_ADDRESS)"")])
  )

  (defcap ADMIN_OR_TEK (account:string)
    (compose-capability (ACCOUNT_GUARD account))
    (compose-capability (PRIVATE))
    (enforce-one "admin or discord" [(enforce (= account ADMIN_ADDRESS) "") (enforce (= account TEK)"")])
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

   (defcap ADMIN() ; Used for admin functions
       @doc "Only allows admin to call these"
       (compose-capability (PRIVATE))
       (compose-capability (ACCOUNT_GUARD ADMIN_ADDRESS))
   )
  
   (defcap SITE_ORACLE (account:string)
       @doc "Only allows the presale site wallet to send information"
       (enforce (= account SITE_ORACLE_ADDRESS) "only the site wallet can call these functions")
       (compose-capability (ACCOUNT_GUARD SITE_ORACLE_ADDRESS))
   )
  
 (defcap GOVERNANCE ()
    (enforce-guard (keyset-ref-guard "n_e98a056e3e14203e6ec18fada427334b21b667d8.chips-admin")))
  ;
  
   (defcap BRIDGE_ORACLE (account:string)
       @doc "Allows the bridge oracle account to do its job"
       (enforce (= account BRIDGE_ORACLE_ADDRESS) "only the bridge wallet can call these functions")
       (compose-capability (ACCOUNT_GUARD BRIDGE_ORACLE_ADDRESS))
   )
)

(create-table role-table)
(create-table discount-table)

(create-table counts-table)
(create-table price-table)
(create-table sold-table)
(create-table sold-history-table)
(create-table mineable-coins-table)
(create-table bridge-tx-table)
(create-table expected-rewards-table)
(create-table james-table)
(create-table mined-table)
(create-table live-hashrate-table)
(create-table loaded-hashrate-table)
(create-table promotion-table)
(create-table electric-table)
(create-table guard-storage-table)
(create-table kmc-discount-table)
(initialize)
