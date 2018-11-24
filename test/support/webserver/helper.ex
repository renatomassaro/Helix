defmodule Helix.Test.Webserver.Helper do

  alias Helix.Log.Model.Log
  alias Helix.Server.Model.Server

  def path(:ping, _),
    do: {"GET", [path_version(), "ping"], Helix.Session.Requests.Ping}
  def path(:subscribe, _),
    do: {"GET", [path_version(), "subscribe"], Helix.Session.Requests.Subscribe}
  def path(:log_forge_create, [server_id]),
    do: {"POST", server_scope(server_id) ++ ["log"], Helix.Log.Requests.Forge.Create}
  def path(:log_forge_edit, [server_id, log_id]),
    do: {"POST", log_scope(server_id, log_id), Helix.Log.Requests.Forge.Edit}

  defp main_scope,
    do: [path_version()]

  defp server_scope(server_id = %Server.ID{}),
    do: server_scope({:server_id, server_id})
  defp server_scope({:server_id, server_id}),
    do: [main_scope(), "server", str_helix_id(server_id)]

  defp log_scope(server_id = %Server.ID{}, log_id = %Log.ID{}),
    do: [server_scope(server_id), "log", str_helix_id(log_id), "edit"]

  defp str_helix_id(id),
    do: id |> to_string |> String.replace(":", ",")

  defp path_version,
    do: "v1"
end
