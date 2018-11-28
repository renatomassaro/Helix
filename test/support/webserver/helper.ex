defmodule Helix.Test.Webserver.Helper do

  alias Helix.Log.Model.Log
  alias Helix.Server.Model.Server

  # Log scope ("/server/:server_cid/log/:log_id/*")

  def path(:log_forge_edit, [server_id, log_id]) do
    {
      "POST",
      log_scope(server_id, log_id) ++ ["edit"],
      Helix.Log.Request.Forge.Edit
    }
  end

  def path(:log_recover_custom, [server_id, log_id]) do
    {
      "POST",
      log_scope(server_id, log_id) ++ ["recover"],
      Helix.Log.Request.Recover.Custom
    }
  end

  # Server scope ("/server/:server_cid/*")

  def path(:log_recover_global, [server_id]) do
    {
      "POST",
      server_scope(server_id) ++ ["log", "recover"],
      Helix.Log.Request.Recover.Global
    }
  end

  def path(:log_forge_create, [server_id]) do
    {"POST", server_scope(server_id) ++ ["log"], Helix.Log.Request.Forge.Create}
  end

  def path(:log_paginate, [server_id]),
    do: {"GET", server_scope(server_id) ++ ["log"], Helix.Log.Request.Paginate}

  # Main scope ("/")

  def path(:subscribe, _),
    do: {"GET", [path_version(), "subscribe"], Helix.Session.Request.Subscribe}
  def path(:ping, _),
    do: {"GET", [path_version(), "ping"], Helix.Session.Request.Ping}

  # Internals

  defp main_scope,
    do: [path_version()]

  defp server_scope(server_id = %Server.ID{}),
    do: server_scope({:server_id, server_id})
  defp server_scope({:server_id, server_id}),
    do: [main_scope(), "server", str_helix_id(server_id)]

  defp log_scope(server_id = %Server.ID{}, log_id = %Log.ID{}),
    do: [server_scope(server_id), "log", str_helix_id(log_id)]

  defp str_helix_id(id),
    do: id |> to_string |> String.replace(":", ",")

  defp path_version,
    do: "v1"
end
