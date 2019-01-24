defmodule Helix.Software.Request.File.UploadTest do

  use Helix.Test.Case.Integration

  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Software.Query.Storage, as: StorageQuery
  alias Helix.Software.Request.File.Upload, as: FileUploadRequest

  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Helper, as: SoftwareHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @session SessionHelper.mock_session!(:server_remote)

  describe "check_params/2" do
    test "validates and casts expected data" do
      file_id = SoftwareHelper.id()
      storage_id = SoftwareHelper.storage_id()

      params = %{
        "file_id" => to_string(file_id),
        "storage_id" => to_string(storage_id)
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        FileUploadRequest.check_params(request, @session)

      assert request.params.file_id == file_id
      assert request.params.storage_id == storage_id
    end

    test "uses main storage_id if none was given" do
      {session, %{endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      endpoint_storage_id = StorageQuery.get_main_storage_id(endpoint.server_id)
      file_id = SoftwareHelper.id()

      params = %{
        "file_id" => to_string(file_id),
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        FileUploadRequest.check_params(request, session)

      assert request.params.file_id == file_id
      assert request.params.storage_id == endpoint_storage_id
    end

    test "rejects upload on local connection" do
      session = SessionHelper.mock_session!(:server_local)

      params = %{
        "file_id" => to_string(SoftwareHelper.id()),
        "storage_id" => to_string(SoftwareHelper.storage_id())
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:error, _, reason} =
        FileUploadRequest.check_params(request, session)

      assert reason == :upload_self
    end
  end

  describe "check_permissions/2" do
    test "accepts when everything is OK" do
      {session, %{gateway: gateway, endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      file = SoftwareSetup.file!(server_id: gateway.server_id)
      endpoint_storage = StorageQuery.get_main_storage(endpoint)

      params = %{
        "file_id" => to_string(file.file_id),
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        RequestHelper.check_permissions(FileUploadRequest, request, session)


      assert request.meta.gateway == gateway
      assert request.meta.endpoint == endpoint
      assert request.meta.file == file
      assert request.meta.storage == endpoint_storage
    end

    test "rejects if invalid file was passed" do
      {session, %{endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      params = %{
        "file_id" => to_string(SoftwareHelper.id()),
        "storage_id" => to_string(SoftwareHelper.storage_id())
      }

      request = RequestHelper.mock_request(unsafe: params)

      # As expected, failed
      assert {:error, _, reason} =
        RequestHelper.check_permissions(FileUploadRequest, request, session)
      assert reason == {:file, :not_found}

      # Now we'll create the file... on the endpoint! So, the gateway is
      # attempting to upload a file on the endpoint. But this file
      # exists on the endpoint itself, not the gateway. OMFG!
      file = SoftwareSetup.file!(server_id: endpoint.server_id)

      params = %{
        "file_id" => to_string(file.file_id),
        "storage_id" => to_string(SoftwareHelper.storage_id())
      }

      request = RequestHelper.mock_request(unsafe: params)

      # Failed again!
      assert {:error, _, reason} =
        RequestHelper.check_permissions(FileUploadRequest, request, session)
      assert reason == {:file, :not_found}
    end

    test "rejects if invalid storage was passed" do
      {session, %{gateway: gateway}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      # Valid file that we'll be uploading
      file = SoftwareSetup.file!(server_id: gateway.server_id)

      # Notice `storage_id` is random
      params = %{
        "file_id" => to_string(file.file_id),
        "storage_id" => to_string(SoftwareHelper.storage_id())
      }

      request = RequestHelper.mock_request(unsafe: params)

      # As expected, failed
      assert {:error, _, reason} =
        RequestHelper.check_permissions(FileUploadRequest, request, session)
      assert reason == {:storage, :not_found}

      # Now we'll try again... With the gateway storage. So, the gateway
      # is attempting to upload a file that exists on itself. But the
      # upload will target the gateway's own storage id! OMFG!
      gateway_storage_id = StorageQuery.get_main_storage_id(gateway)


      # Notice `storage_id` is random
      params = %{
        "file_id" => to_string(file.file_id),
        "storage_id" => to_string(gateway_storage_id)
      }

      request = RequestHelper.mock_request(unsafe: params)

      # As expected, failed
      assert {:error, _, reason} =
        RequestHelper.check_permissions(FileUploadRequest, request, session)
      assert reason == {:storage, :not_belongs}
    end
  end

  describe "handle_request/2" do
    test "starts the process" do
      {session, %{gateway: gateway, endpoint: endpoint}} =
        SessionHelper.mock_session(:server_remote, with_servers: true)

      file = SoftwareSetup.file!(server_id: gateway.server_id)
      endpoint_storage = StorageQuery.get_main_storage(endpoint)

      params = %{
        "file_id" => to_string(file.file_id),
      }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, _request} =
        RequestHelper.handle_request(FileUploadRequest, request, session)

      # Ensure process was created
      [process] = ProcessQuery.get_processes_on_server(gateway)

      assert process.source_entity_id == session.entity_id
      assert process.target_id == endpoint.server_id

      assert process.type == :file_upload
      assert process.data.connection_type == :ftp
      assert process.data.type == :upload
      assert process.data.destination_storage_id == endpoint_storage.storage_id

      assert process.tgt_file_id == file.file_id

      TOPHelper.top_stop(gateway)
    end
  end
end
