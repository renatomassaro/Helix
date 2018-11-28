defmodule Helix.Test.Webserver.Helper do

  alias Helix.Log.Model.Log
  alias Helix.Network.Model.Bounce
  alias Helix.Server.Model.Server

  ##############################################################################
  # Log scope ("/server/:server_cid/log/:log_id/*")
  ##############################################################################

  # POST /server/:server_cid/log/:log_id/recover
  def path(:log_recover_custom, [server_id, log_id]) do
    {
      "POST",
      log_scope(server_id, log_id) ++ ["recover"],
      Helix.Log.Request.Recover.Custom
    }
  end

  # PUT /server/:server_cid/log/:log_id
  def path(:log_forge_edit, [server_id, log_id]),
    do: {"PUT", log_scope(server_id, log_id), Helix.Log.Request.Forge.Edit}

  ##############################################################################
  # Server scope ("/server/:server_cid/*")
  ##############################################################################

  # POST /server/:server_cid/log/recover
  def path(:log_recover_global, [server_id]) do
    {
      "POST",
      server_scope(server_id) ++ ["log", "recover"],
      Helix.Log.Request.Recover.Global
    }
  end

  # POST /server/:server_cid/log
  def path(:log_forge_create, [server_id]) do
    {"POST", server_scope(server_id) ++ ["log"], Helix.Log.Request.Forge.Create}
  end

  # GET /server/:server_cid/log
  def path(:log_paginate, [server_id]),
    do: {"GET", server_scope(server_id) ++ ["log"], Helix.Log.Request.Paginate}

  # GET /server/:server_cid/browse
  def path(:browse, [server_id]) do
    {"GET", server_scope(server_id) ++ ["browse"], Helix.Network.Request.Browse}
  end

  ##############################################################################
  # Bounce scope ("/bounce/:bounce_id")
  ##############################################################################

  # PUT /bounce/:bounce_id
  def path(:bounce_update, [bounce_id]),
    do: {"PUT", bounce_scope(bounce_id), Helix.Network.Request.Bounce.Update}

  # DELETE /bounce/:bounce_id
  def path(:bounce_remove, [bounce_id]),
    do: {"DELETE", bounce_scope(bounce_id), Helix.Network.Request.Bounce.Remove}

  ##############################################################################
  # Main scope ("/")
  ##############################################################################

  # POST /bounce
  def path(:bounce_create, _),
    do: {"POST", [path_version(), "post"], Helix.Network.Request.Bounce.Create}

  # GET /subscribe
  def path(:subscribe, _),
    do: {"GET", [path_version(), "subscribe"], Helix.Session.Request.Subscribe}

  # GET /ping
  def path(:ping, _),
    do: {"GET", [path_version(), "ping"], Helix.Session.Request.Ping}

  ##############################################################################
  # Internals
  ##############################################################################

  defp main_scope,
    do: [path_version()]

  defp bounce_scope(bounce_id = %Bounce.ID{}),
    do: [main_scope(), "bounce", str_helix_id(bounce_id)]

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
