defmodule Helix.Test.Features.File.TransferTest do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  import Helix.Test.Log.Macros

  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Software.Model.File
  alias Helix.Software.Query.File, as: FileQuery

  alias Helix.Test.Log.Helper, as: LogHelper
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Software.Helper, as: SoftwareHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @moduletag :feature

  describe "file.download" do
    test "download lifecycle" do
      %{
        local: %{gateway: gateway, entity: entity},
        remote: %{endpoint: endpoint},
        session: session,
        bounce: bounce
      } = SessionSetup.create_remote(with_bounce: true)

      sse_subscribe(session)

      endpoint_nip = ServerHelper.get_nip(endpoint)
      gateway_storage = SoftwareHelper.get_storage(gateway)
      {dl_file, _} = SoftwareSetup.file(server_id: endpoint.server_id)

      conn =
        conn()
        |> infer_path(:file_download, [endpoint_nip, dl_file.file_id])
        |> set_session(session)
        |> execute()

      assert_status conn, 200

      # Client-defined request_id is TODO \/
      # # Download is acknowledge (`:ok`). Contains the `request_id`.
      # assert response.meta.request_id == request_id
      # assert response.data == %{}

      # # After a while, client receives the new process through top recalque
      # [l_top_recalcado_event, l_process_created_event] =
      #   wait_events [:top_recalcado, :process_created]

      # # Each one have the client-defined request_id
      # assert l_top_recalcado_event.meta.request_id == request_id
      # assert l_process_created_event.meta.request_id == request_id

      [process_created_event] = wait_events [:process_created]

      process = ProcessQuery.fetch(process_created_event.data.process_id)

      assert process.type == :file_download
      assert process.data.connection_type == :ftp
      assert process.data.destination_storage_id == gateway_storage.storage_id
      assert process.data.type == :download

      # Force completion of the process
      # Due to forced completion, we won't have the `request_id` information
      # on the upcoming events available on our tests. But they should exist on
      # real life.
      TOPHelper.force_completion(process)

      [file_downloaded_event, file_added_event, notification_added_event] =
        wait_events [:file_downloaded, :file_added, :notification_added]

      # Process no longer exists
      refute ProcessQuery.fetch(process.process_id)

      # The new file exists on my server
      new_file =
        file_downloaded_event.data.file.id
        |> File.ID.cast!()
        |> FileQuery.fetch()

      assert new_file.storage_id == gateway_storage.storage_id

      # The old file still exists on the target server, as expected
      r_file = FileQuery.fetch(dl_file.file_id)
      assert r_file.storage_id == SoftwareHelper.get_storage_id(endpoint)

      # Client received the FileAddedEvent
      assert file_added_event.data.file.id == to_string(new_file.file_id)

      # Client received the NotificationAddedEvent
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "file_downloaded"

      # Notification contains information about which server it took place
      assert notification_added_event.data.server_id ==
        to_string(gateway.server_id)

      # Notification contains required data
      notification_data = notification_added_event.data.data
      assert notification_data.id == to_string(new_file.file_id)
      assert notification_data.name == new_file.name
      assert notification_data.type == to_string(new_file.software_type)
      assert notification_data.extension
      assert notification_data.version

      # Now let's check the log generation

      log_gateway = LogHelper.get_last_log(gateway, :file_download_gateway)

      file_name = LogHelper.log_file_name(dl_file)

      assert_log log_gateway, gateway.server_id, entity.entity_id,
        :file_download_gateway, %{file_name: file_name}

      # Verify logging worked correctly within the bounce nodes
      assert_bounce bounce, gateway, endpoint, entity

      log_endpoint =
        LogHelper.get_last_log(endpoint, :file_download_endpoint)

      # Log on endpoint (`<someone>` downloaded file at `endpoint`)
      assert_log log_endpoint, endpoint.server_id, entity.entity_id,
        :file_download_endpoint, %{file_name: file_name}

      # TODO: #388 Underlying connection(s) were removed

      TOPHelper.top_stop(gateway)
    end
  end

  describe "file.upload" do
    test "upload lifecycle" do
      %{
        local: %{gateway: gateway, entity: entity},
        remote: %{endpoint: endpoint},
        session: session,
        bounce: bounce
      } = SessionSetup.create_remote(with_bounce: true)

      sse_subscribe(session)

      endpoint_nip = ServerHelper.get_nip(endpoint)
      endpoint_storage = SoftwareHelper.get_storage(endpoint)
      {up_file, _} = SoftwareSetup.file(server_id: gateway.server_id)

      conn =
        conn()
        |> infer_path(:file_upload, [endpoint_nip, up_file.file_id])
        |> set_session(session)
        |> execute()

      assert_status conn, 200

      [process_created_event] = wait_events [:process_created]

      process = ProcessQuery.fetch(process_created_event.data.process_id)

      assert process.type == :file_upload
      assert process.data.connection_type == :ftp
      assert process.data.destination_storage_id == endpoint_storage.storage_id
      assert process.data.type == :upload

      # Force completion of the process
      # Due to forced completion, we won't have the `request_id` information
      # on the upcoming events available on our tests. But they should exist on
      # real life.
      TOPHelper.force_completion(process)

      [file_uploaded_event, file_added_event, notification_added_event] =
        wait_events [:file_uploaded, :file_added, :notification_added]

      # Process no longer exists
      refute ProcessQuery.fetch(process.process_id)

      # The new file exists on the endpoint
      new_file =
        file_uploaded_event.data.file.id
        |> File.ID.cast!()
        |> FileQuery.fetch()

      assert new_file.storage_id == endpoint_storage.storage_id

      # The old file still exists on the gateway server, as expected
      l_file = FileQuery.fetch(up_file.file_id)
      assert l_file.storage_id == SoftwareHelper.get_storage_id(gateway)

      # Client received the FileAddedEvent
      assert file_added_event.data.file.id == to_string(new_file.file_id)

      # Client received the NotificationAddedEvent
      assert notification_added_event.data.class == "server"
      assert notification_added_event.data.code == "file_uploaded"

      # Notification contains information about which server it took place
      assert notification_added_event.data.ip == endpoint_nip.ip
      assert notification_added_event.data.network_id ==
        to_string(endpoint_nip.network_id)

      # Notification contains required data
      notification_data = notification_added_event.data.data
      assert notification_data.id == to_string(new_file.file_id)
      assert notification_data.name == new_file.name
      assert notification_data.type == to_string(new_file.software_type)
      assert notification_data.extension
      assert notification_data.version

      # Now let's check the log generation
      log_gateway = LogHelper.get_last_log(gateway, :file_upload_gateway)

      file_name = LogHelper.log_file_name(up_file)

      assert_log log_gateway, gateway.server_id, entity.entity_id,
        :file_upload_gateway, %{file_name: file_name}

      # Verify logging worked correctly within the bounce nodes
      assert_bounce bounce, gateway, endpoint, entity

      log_endpoint =
        LogHelper.get_last_log(endpoint, :file_upload_endpoint)

      # Log on endpoint (`<someone>` uploaded file at `endpoint`)
      assert_log log_endpoint, endpoint.server_id, entity.entity_id,
        :file_upload_endpoint, %{file_name: file_name}

      # TODO: #388 Underlying connection(s) were removed

      TOPHelper.top_stop(gateway)
    end
  end
end
