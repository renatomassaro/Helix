defmodule Helix.Account.Query.Email do

  alias Helix.Account.Model.Email
  alias Helix.Account.Internal.Email, as: EmailInternal

  defdelegate fetch_verification_by_key(verification),
    to: EmailInternal
end
