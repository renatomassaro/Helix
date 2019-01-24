defmodule Helix.Test.Features.File.InstallTest do

  use Helix.Test.Case.Integration
  use Helix.Test.Webserver

  import Helix.Test.Case.ID

  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Software.Model.Virus
  alias Helix.Software.Query.File, as: FileQuery
  alias Helix.Software.Query.Virus, as: VirusQuery

  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Software.Helper, as: SoftwareHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @moduletag :feature

  describe "file.install" do

    # TODO: Test locally
    test "install lifecycle (virus)" do
      %{
        local: %{gateway: gateway, entity: entity},
        remote: %{endpoint: endpoint},
        session: session,
      } = SessionSetup.create_remote()

      sse_subscribe(session)

      endpoint_nip = ServerHelper.get_nip(endpoint)

      # First, let's attempt to install a virus that does not exist!
      conn =
        conn()
        |> infer_path(:file_install, [endpoint_nip, SoftwareHelper.id()])
        |> set_session(session)
        |> execute()

      # It failed, as expected!
      assert_resp_error conn, {:file, :not_found}

      # Now let's try again with an actual file (virus)!
      file = SoftwareSetup.virus!(server_id: endpoint.server_id)

      conn =
        conn()
        |> infer_path(:file_install, [endpoint_nip, file.file_id])
        |> set_session(session)
        |> execute()

      # It worked!
      assert_status conn, 200

      # After a while, client receives the new process through top recalque
      [process_created_event] = wait_events [:process_created]

      assert process_created_event.domain == "server"
      assert process_created_event.data.type == "install_virus"

      # Force completion of the process
      process = ProcessQuery.fetch(process_created_event.data.process_id)
      TOPHelper.force_completion(process)

      # Process no longer exists
      refute ProcessQuery.fetch(process.process_id)

      # Virus has been installed
      virus = VirusQuery.fetch(process.tgt_file_id)

      assert %Virus{} = virus
      assert virus.file_id == file.file_id
      assert virus.entity_id == entity.entity_id
      assert virus.is_active?

      # The file metadata returns it as installed
      new_file = FileQuery.fetch(file.file_id)
      assert new_file.meta.installed?

      # Client receives confirmation that the virus has been installed
      [virus_installed] = wait_events [:virus_installed]

      assert_id virus_installed.data.file.id, file.file_id
      assert_id virus_installed.meta.process_id, process.process_id

      TOPHelper.top_stop(gateway)
    end
  end
end
