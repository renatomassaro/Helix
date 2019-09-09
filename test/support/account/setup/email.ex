defmodule Helix.Test.Account.Setup.Email do

  alias Ecto.Changeset
  alias Helix.Account.Model.Email
  alias Helix.Account.Repo, as: AccountRepo

  alias Helix.Test.Account.Setup, as: AccountSetup

  @doc """
  See docs on `fake_email_verification/1`
  """
  def email_verification(opts \\ []) do
    {verification, related} = fake_email_verification(opts)

    {:ok, inserted} = AccountRepo.insert(verification)

    {inserted, related}
  end
  def email_verification!(opts \\ []),
    do: email_verification(opts) |> elem(0)

  @doc """
  Opts:
  - account_id: Which account id to use. If none specified, new one is generated
  """
  def fake_email_verification(opts \\ []) do
    {account, account_id} =
      if opts[:account_id] do
        {nil, opts[:account_id]}
      else
        account = AccountSetup.account!(skip_verification: true)
        {account, account.account_id}
      end

    changeset = Email.Verification.create_changeset(%{account_id: account_id})

    email_verification = Changeset.apply_changes(changeset)

    related =
      %{
        changeset: changeset,
        account: account
      }

    {email_verification, related}
  end
end
