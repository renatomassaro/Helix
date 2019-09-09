defmodule Helix.Test.Account.Helper.Email do

  alias HELL.Password

  def verification_key,
    do: Password.generate(:verification_key)
end
