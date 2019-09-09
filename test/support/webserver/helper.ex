defmodule Helix.Test.Webserver.Helper do

  alias Helix.Log.Model.Log
  alias Helix.Network.Model.Bounce
  alias Helix.Server.Model.Server
  alias Helix.Software.Model.File

  alias Helix.Test.Network.Helper, as: NetworkHelper

  @internet_id NetworkHelper.internet_id()

  ##############################################################################
  # Server-File-ID scope ("/server/:server_cid/file/:file_id/*")
  ##############################################################################

  # POST /server/:server_cid/file/:file_id/install
  def path(:file_install, [server_id, file_id]) do
    {
      "POST",
      server_file_id_scope(server_id, file_id) ++ ["install"],
      Helix.Software.Request.File.Install
    }
  end

  ##############################################################################
  # Server-File scope ("/server/:server_cid/file/*")
  ##############################################################################

  ##############################################################################
  # Server-Log-ID scope ("/server/:server_cid/log/:log_id/*")
  ##############################################################################

  # POST /server/:server_cid/log/:log_id/recover
  def path(:log_recover_custom, [server_id, log_id]) do
    {
      "POST",
      server_log_id_scope(server_id, log_id) ++ ["recover"],
      Helix.Log.Request.Recover.Custom
    }
  end

  # PUT /server/:server_cid/log/:log_id
  def path(:log_forge_edit, [server_id, log_id]) do
    {
      "PUT",
      server_log_id_scope(server_id, log_id),
      Helix.Log.Request.Forge.Edit
    }
  end

  ##############################################################################
  # Server-Log scope ("/server/:server_cid/log/*")
  ##############################################################################

  # POST /server/:server_cid/log/recover
  def path(:log_recover_global, [server_id]) do
    {
      "POST",
      server_log_scope(server_id) ++ ["recover"],
      Helix.Log.Request.Recover.Global
    }
  end

  # POST /server/:server_cid/log
  def path(:log_forge_create, [server_id]) do
    {"POST", server_log_scope(server_id), Helix.Log.Request.Forge.Create}
  end

  # GET /server/:server_cid/log
  def path(:log_paginate, [server_id]),
    do: {"GET", server_log_scope(server_id), Helix.Log.Request.Paginate}

  ##############################################################################
  # Server scope ("/server/:server_cid/*")
  ##############################################################################

  # GET /server/:server_cid/browse
  def path(:browse, [server_id]) do
    {"GET", server_scope(server_id) ++ ["browse"], Helix.Network.Request.Browse}
  end

  ##############################################################################
  # Gateway-Bruteforce scope ("/gateway/:gateway_id/bruteforce/*")
  ##############################################################################

  # POST /gateway/:gateway_id/bruteforce/:target_nip
  def path(:bruteforce, [gateway_id, target_nip]) do
    {
      "POST",
      gateway_bruteforce_scope(gateway_id, target_nip),
      Helix.Software.Request.Cracker.Bruteforce
    }
  end

  ##############################################################################
  # Gateway scope ("/gateway/:gateway_id/*")
  ##############################################################################

  ##############################################################################
  # Endpoint-File-ID scope ("/endpoint/:endpoint_nip/file/:file_id/*")
  ##############################################################################

  # POST /endpoint/:endpoint_nip/file/:file_id/download
  def path(:file_download, [endpoint_nip, file_id]) do
    {
      "POST",
      endpoint_file_id_scope(endpoint_nip, file_id) ++ ["download"],
      Helix.Software.Request.File.Download
    }
  end

  # POST /endpoint/:endpoint_id/file/:file_id/upload
  def path(:file_upload, [endpoint_nid, file_id]) do
    {
      "POST",
      endpoint_file_id_scope(endpoint_nid, file_id) ++ ["upload"],
      Helix.Software.Request.File.Upload
    }
  end

  ##############################################################################
  # Endpoint scope ("/endpoint/:endpoint_nip/*")
  ##############################################################################

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
  # Account scope ("/account/*")
  ##############################################################################

  # POST /account/check-username
  def path(:account_check_username, _) do
    {
      "POST",
      account_scope("check-username"),
      Helix.Account.Request.CheckUsername
    }
  end

  # POST /account/check-email
  def path(:account_check_email, _),
    do: {"POST", account_scope("check-email"), Helix.Account.Request.CheckEmail}

  # POST /account/register
  def path(:account_register, _),
    do: {"POST", account_scope("register"), Helix.Account.Request.Register}

  ##############################################################################
  # Document scope ("/document/*")
  ##############################################################################

  def path(:document_fetch_tos, _),
    do: {"GET", document_scope("tos"), Helix.Account.Request.Document.Fetch}

  def path(:document_fetch_pp, _),
    do: {"GET", document_scope("pp"), Helix.Account.Request.Document.Fetch}

  def path(:document_sign_tos, _) do
    {
      "POST",
      [document_scope("tos"), "sign"],
      Helix.Account.Request.Document.Sign
    }
  end

  def path(:document_sign_pp, _) do
    {
      "POST",
      [document_scope("pp"), "sign"],
      Helix.Account.Request.Document.Sign
    }
  end

  ##############################################################################
  # Storyline scope ("/story/*")
  ##############################################################################

  def path(:story_restart, _),
    do: {"POST", [story_scope("restart")], Helix.Story.Request.Restart}

  ##############################################################################
  # Main scope ("/")
  ##############################################################################

  # POST /virus/collect
  def path(:virus_collect, _) do
    {
      "POST",
      [path_version(), "virus", "collect"],
      Helix.Software.Request.Virus.Collect
    }
  end

  # POST /bounce
  def path(:bounce_create, _) do
    {"POST", [path_version(), "bounce"], Helix.Network.Request.Bounce.Create}
  end

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

  defp account_scope(path),
    do: [main_scope(), "account", path]

  defp story_scope(path),
    do: [main_scope(), "story", path]

  defp document_scope(path),
    do: [main_scope(), "document", path]

  defp bounce_scope(bounce_id = %Bounce.ID{}),
    do: [main_scope(), "bounce", str_helix_id(bounce_id)]

  # Server

  defp server_scope(server_id = %Server.ID{}),
    do: server_scope({:server_id, server_id})
  defp server_scope(nip = %{network_id: _, ip: _}),
    do: server_scope({:server_nip, nip})
  defp server_scope({:server_id, server_id}),
    do: [main_scope(), "server", str_helix_id(server_id)]
  defp server_scope({:server_nip, nip}),
    do: [main_scope(), "server", str_nip(nip)]

  defp server_log_scope(server_cid),
    do: [server_scope(server_cid), "log"]
  defp server_log_id_scope(server_cid, log_id = %Log.ID{}),
    do: [server_log_scope(server_cid), str_helix_id(log_id)]

  defp server_file_scope(server_cid),
    do: [server_scope(server_cid), "file"]
  defp server_file_id_scope(server_cid, file_id = %File.ID{}),
    do: [server_file_scope(server_cid), str_helix_id(file_id)]

  # Gateway

  defp gateway_scope(gateway_id = %Server.ID{}),
    do: [main_scope(), "gateway", str_helix_id(gateway_id)]

  defp gateway_bruteforce_scope(gateway_id, tgt_nip = %{network_id: _, ip: _}),
    do: [gateway_scope(gateway_id), "bruteforce", str_nip(tgt_nip)]

  # Endpoint

  defp endpoint_scope(endpoint_nip),
    do: [main_scope(), "endpoint", str_nip(endpoint_nip)]

  defp endpoint_file_scope(endpoint_nip),
    do: [endpoint_scope(endpoint_nip), "file"]
  defp endpoint_file_id_scope(endpoint_nip, file_id = %File.ID{}),
    do: [endpoint_file_scope(endpoint_nip), str_helix_id(file_id)]

  # Utils

  defp str_helix_id(id),
    do: id |> to_string |> String.replace(":", ",")
  defp str_nip(%{network_id: @internet_id, ip: ip}),
    do: ip <> "$*"
  defp str_nip(%{network_id: network_id, ip: ip}),
    do: ip <> "$" <> str_helix_id(network_id)

  defp path_version,
    do: "v1"
end
