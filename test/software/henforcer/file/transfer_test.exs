defmodule Helix.Software.Henforcer.FileTransferTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Henforcer.Macros

  alias Helix.Software.Henforcer.File.Transfer, as: FileTransferHenforcer

  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Software.Helper, as: SoftwareHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  describe "can_transfer?/5" do
    test "verifies whether the transfer is local" do
      {gateway, _} = ServerSetup.server()
      {endpoint, _} = ServerSetup.server()

      storage_id = SoftwareHelper.get_storage_id(gateway.server_id)
      {file, _} = SoftwareSetup.file(server_id: endpoint.server_id)

      assert {true, relay} =
        FileTransferHenforcer.can_transfer?(
          :download,
          gateway.server_id,
          endpoint.server_id,
          storage_id,
          file.file_id
        )

      assert relay.storage.storage_id == storage_id
      assert relay.file.file_id == file.file_id
      assert relay.gateway == gateway
      assert relay.endpoint == endpoint

      assert_relay relay, [:storage, :file, :gateway, :endpoint]

      # Trying to transfer a file on the same server
      assert {false, reason, _} =
        FileTransferHenforcer.can_transfer?(
          :upload,
          gateway.server_id,
          gateway.server_id,
          storage_id,
          file.file_id
        )
      assert reason == {:target, :self}
    end

    test "verifies whether the file belongs to the server" do
      {gateway, _} = ServerSetup.server()
      {endpoint, _} = ServerSetup.server()

      gateway_storage_id = SoftwareHelper.get_storage_id(gateway.server_id)
      endpoint_storage_id =
        SoftwareHelper.get_storage_id(endpoint.server_id)

      gateway_file = SoftwareSetup.file!(server_id: gateway.server_id)
      endpoint_file = SoftwareSetup.file!(server_id: endpoint.server_id)

      # Downloading a file from `endpoint`
      assert {true, relay_download} =
        FileTransferHenforcer.can_transfer?(
          :download,
          gateway.server_id,
          endpoint.server_id,
          gateway_storage_id,
          endpoint_file.file_id
        )

      assert relay_download.gateway == gateway
      assert relay_download.endpoint == endpoint
      assert_relay relay_download, [:storage, :file, :gateway, :endpoint]

      # Trying to download a file that belongs to the gateway...
      assert {false, reason1, _} =
        FileTransferHenforcer.can_transfer?(
          :download,
          gateway.server_id,
          endpoint.server_id,
          gateway_storage_id,
          gateway_file.file_id
        )

      # Uploading file that exists on gateway
      assert {true, relay_upload} =
        FileTransferHenforcer.can_transfer?(
          :upload,
          gateway.server_id,
          endpoint.server_id,
          endpoint_storage_id,
          gateway_file.file_id
        )

      assert relay_upload.gateway == gateway
      assert relay_upload.endpoint == endpoint
      assert_relay relay_upload, [:storage, :file, :gateway, :endpoint]

      # Trying to upload a file that belongs to the endpoint...
      assert {false, reason2, _} =
        FileTransferHenforcer.can_transfer?(
          :upload,
          gateway.server_id,
          endpoint.server_id,
          endpoint_storage_id,
          endpoint_file.file_id
        )

      assert reason1 == {:file, :not_belongs}
      assert reason1 == reason2
    end

    test "verifies whether the storage belongs to the server" do
      {gateway, _} = ServerSetup.server()
      {endpoint, _} = ServerSetup.server()

      endpoint_storage_id =
        SoftwareHelper.get_storage_id(endpoint.server_id)
      gateway_storage_id = SoftwareHelper.get_storage_id(gateway.server_id)

      gateway_file = SoftwareSetup.file!(server_id: gateway.server_id)
      endpoint_file = SoftwareSetup.file!(server_id: endpoint.server_id)

      # Valid file download with valid storage
      assert {true, _} =
        FileTransferHenforcer.can_transfer?(
          :download,
          gateway.server_id,
          endpoint.server_id,
          gateway_storage_id,
          endpoint_file.file_id
        )

      # Downloading valid file but with wrong storage
      assert {false, reason1, _} =
        FileTransferHenforcer.can_transfer?(
          :download,
          gateway.server_id,
          endpoint.server_id,
          endpoint_storage_id,
          endpoint_file.file_id
        )

      # Valid file upload with valid storage
      assert {true, _} =
        FileTransferHenforcer.can_transfer?(
          :upload,
          gateway.server_id,
          endpoint.server_id,
          endpoint_storage_id,
          gateway_file.file_id
        )

      # Uploading valid file but with wrong storage
      assert {false, reason2, _} =
        FileTransferHenforcer.can_transfer?(
          :upload,
          gateway.server_id,
          endpoint.server_id,
          gateway_storage_id,
          gateway_file.file_id
        )

      assert reason1 == {:storage, :not_belongs}
      assert reason1 == reason2
    end

    @tag :pending
    test "verifies whether the storage has enough space"
  end
end
