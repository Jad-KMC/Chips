(interface kwatt-v1

    (defun mint:string (receiver:string amount:decimal)
        @doc "Allows a user to mint kWATT tokens.")

    (defcap MINT:bool ( receiver:string amount:decimal )
      @doc "Allows installation of the mint capability"
      @managed)

)
