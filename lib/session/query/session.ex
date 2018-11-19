defmodule Helix.Session.Query.Session do

  alias Helix.Session.Internal.Session, as: SessionInternal

  defdelegate fetch(session_id),
    to: SessionInternal

  defdelegate fetch_server(session_id, server_id),
    to: SessionInternal

  defdelegate fetch_unsynced(session_id),
    to: SessionInternal

  defdelegate is_sse_active?(session_id),
    to: SessionInternal

  def get_domains_sessions(domains) do
    {domain_server, domain_account} =
      Enum.reduce(domains, {[], []}, fn domain, {acc_server, acc_account} ->
        case domain do
          {:server, server_id} ->
            {[server_id | acc_server], acc_account}

          {:account, account_id} ->
            {acc_server, [account_id | acc_account]}
        end
      end)

    [
      SessionInternal.get_server_domain(domain_server) |
      SessionInternal.get_account_domain(domain_account)
    ]
    |> List.flatten()
    |> Enum.uniq()
  end
end
