defmodule Helix.Session.Query.Session do

  alias Helix.Session.Internal.Session, as: SessionInternal

  defdelegate fetch(session_id),
    to: SessionInternal

  defdelegate fetch_server(session_id, server_id),
    to: SessionInternal

  defdelegate fetch_unsynced(session_id),
    to: SessionInternal
end
