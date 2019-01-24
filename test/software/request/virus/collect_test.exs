defmodule Helix.Software.Request.Virus.CollectTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Macros

  alias Helix.Process.Query.Process, as: ProcessQuery
  alias Helix.Software.Request.Virus.Collect, as: VirusCollectRequest

  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Network.Setup, as: NetworkSetup
  alias Helix.Test.Process.TOPHelper
  alias Helix.Test.Server.Helper, as: ServerHelper
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Session.Setup, as: SessionSetup
  alias Helix.Test.Universe.Bank.Helper, as: BankHelper
  alias Helix.Test.Universe.Bank.Setup, as: BankSetup
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Software.Helper, as: SoftwareHelper
  alias Helix.Test.Software.Setup, as: SoftwareSetup

  @session SessionHelper.mock_session!(:server_local)

  describe "check_params/2" do
     test "validates and casts expected data" do
      gateway_id = ServerHelper.id()
      file1_id = SoftwareHelper.id()
      file2_id = SoftwareHelper.id()
      bounce_id = NetworkHelper.bounce_id()
      atm_id = BankHelper.atm_id()
      account_number = BankHelper.account_number()
      wallet = nil  # 244

      params =
        %{
          "gateway_id" => to_string(gateway_id),
          "viruses" => [to_string(file1_id), to_string(file2_id)],
          "bounce_id" => to_string(bounce_id),
          "atm_id" => to_string(atm_id),
          "account_number" => account_number,
          "wallet" => wallet
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        VirusCollectRequest.check_params(request, @session)

      assert request.params.gateway_id == gateway_id
      assert request.params.bounce_id == bounce_id
      assert request.params.atm_id == atm_id
      assert request.params.account_number == account_number
      assert request.params.viruses == [file1_id, file2_id]
      assert request.params.wallet == wallet
    end

    test "rejects when invalid data is given" do
      gateway_id = ServerHelper.id()
      file1_id = SoftwareHelper.id()
      file2_id = SoftwareHelper.id()
      bounce_id = NetworkHelper.bounce_id()
      atm_id = BankHelper.atm_id()
      account_number = BankHelper.account_number()
      wallet = nil  # 244

      base_params =
        %{
          "gateway_id" => to_string(gateway_id),
          "viruses" => [to_string(file1_id), to_string(file2_id)],
          "bounce_id" => to_string(bounce_id),
          "atm_id" => to_string(atm_id),
          "account_number" => account_number,
          "wallet" => wallet
        }

      # Missing `gateway_id`
      p0 = Map.drop(base_params, ["gateway_id"])

      # Missing `viruses`
      p1 = Map.drop(base_params, ["viruses"])

      # Missing valid payment information
      p2 = Map.drop(base_params, ["atm_id", "account_number", "wallet"])

      # Partial bank account data
      p3 = Map.drop(base_params, ["atm_id"])

      # Invalid entry at `viruses`
      p4 = Map.replace!(base_params, "viruses", ["lol", to_string(file2_id)])

      # Viruses must not be empty
      p5 = Map.replace!(base_params, "viruses", [])

      req0 = RequestHelper.mock_request(unsafe: p0)
      req1 = RequestHelper.mock_request(unsafe: p1)
      req2 = RequestHelper.mock_request(unsafe: p2)
      req3 = RequestHelper.mock_request(unsafe: p3)
      req4 = RequestHelper.mock_request(unsafe: p4)
      req5 = RequestHelper.mock_request(unsafe: p5)

      assert {:error, _, er0} = VirusCollectRequest.check_params(req0, @session)
      assert {:error, _, er1} = VirusCollectRequest.check_params(req1, @session)
      assert {:error, _, er2} = VirusCollectRequest.check_params(req2, @session)
      assert {:error, _, er3} = VirusCollectRequest.check_params(req3, @session)
      assert {:error, _, er4} = VirusCollectRequest.check_params(req4, @session)
      assert {:error, _, er5} = VirusCollectRequest.check_params(req5, @session)

      assert er0 == :bad_request
      assert er1 == er0
      assert er2 == er1
      assert er3 == er2
      assert er5 == er3

      assert er4 == :bad_virus
    end
  end

  describe "check_permissions/2" do
    test "accepts when data is valid" do
      %{
        local: %{gateway: gateway, entity: entity},
        session: session
      } = SessionSetup.create_local()

      bounce = NetworkSetup.Bounce.bounce!(entity_id: entity.entity_id)
      bank_account = BankSetup.account!(owner_id: entity.entity_id)

      {virus1, %{file: file1}} =
        SoftwareSetup.Virus.virus(
          entity_id: entity.entity_id,
          is_active?: true,
          real_file?: true
        )

      {virus2, %{file: file2}} =
        SoftwareSetup.Virus.virus(
          entity_id: entity.entity_id,
          is_active?: true,
          real_file?: true
        )

      params =
        %{
          "gateway_id" => gateway.server_id,
          "viruses" => [file1.file_id, file2.file_id],
          "bounce_id" => bounce.bounce_id,
          "atm_id" => bank_account.atm_id,
          "account_number" => bank_account.account_number,
          "wallet" => nil
        }

      request = RequestHelper.mock_request(unsafe: params)

      assert {:ok, request} =
        RequestHelper.check_permissions(VirusCollectRequest, request, session)

      assert request.meta.gateway == gateway
      assert request.meta.payment_info == {bank_account, nil}
      assert request.meta.bounce == bounce

      assert [
        %{file: req_file1, virus: req_virus1},
        %{file: req_file2, virus: req_virus2},
      ] = request.meta.viruses

      assert req_file1 == file1
      assert_map req_virus1, virus1, skip: :running_time

      assert req_file2 == file2
      assert_map req_virus2, virus2, skip: :running_time
    end

    test "rejects when bad things happen" do
      # NOTE: Aggregating several test into one to avoid recreating heavy stuff
      %{
        local: %{gateway: gateway, entity: entity},
        session: session
      } = SessionSetup.create_local()

      {server, _} = ServerSetup.server()

      {_virus1, %{file: file1}} =
        SoftwareSetup.Virus.virus(
          entity_id: entity.entity_id,
          is_active?: true,
          real_file?: true
        )

      {_virus2, %{file: file2}} =
        SoftwareSetup.Virus.virus(
          entity_id: entity.entity_id,
          is_active?: true,
          real_file?: true
        )

      {_, %{file: inactive}} =
        SoftwareSetup.Virus.virus(
          entity_id: entity.entity_id,
          is_active?: false,
          real_file?: true
        )

      gateway_storage_id = SoftwareHelper.get_storage_id(gateway)
      cracker = SoftwareSetup.cracker!(storage_id: gateway_storage_id)

      bounce = NetworkSetup.Bounce.bounce!(entity_id: entity.entity_id)
      bad_bounce = NetworkSetup.Bounce.bounce!()

      bank_account = BankSetup.account!(owner_id: entity.entity_id)
      bad_account = BankSetup.account!(atm_id: bank_account.atm_id)

      base_params =
        %{
          "gateway_id" => gateway.server_id,
          "viruses" => [file1.file_id, file2.file_id],
          "bounce_id" => bounce.bounce_id,
          "atm_id" => bank_account.atm_id,
          "account_number" => bank_account.account_number,
          "wallet" => nil
        }

      ### Test 0: `gateway_id` is not owned by the entity
      p0 = Map.replace!(base_params, "gateway_id", server.server_id)
      req0 = RequestHelper.mock_request(unsafe: p0)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(VirusCollectRequest, req0, session)
      assert reason == {:server, :not_belongs}

      ### Test 1: BankAccount is not owned by the entity
      p1 =
        Map.replace!(base_params, "account_number", bad_account.account_number)
      req1 = RequestHelper.mock_request(unsafe: p1)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(VirusCollectRequest, req1, session)
      assert reason == {:bank_account, :not_belongs}

      ### Test 2: Bounce may not be used
      p2 = Map.replace!(base_params, "bounce_id", bad_bounce.bounce_id)
      req2 = RequestHelper.mock_request(unsafe: p2)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(VirusCollectRequest, req2, session)
      assert reason == {:bounce, :not_belongs}

      ### Test 3: A cracker is not a virus!
      p3 = Map.replace!(base_params, "viruses", [file1.file_id, cracker.file_id])
      req3 = RequestHelper.mock_request(unsafe: p3)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(VirusCollectRequest, req3, session)
      assert reason == {:virus, :not_found}

      ### Test 4: Collecting from a virus that is not active
      p4 =
        Map.replace!(base_params, "viruses", [file1.file_id, inactive.file_id])
      req4 = RequestHelper.mock_request(unsafe: p4)

      assert {:error, _, reason} =
        RequestHelper.check_permissions(VirusCollectRequest, req4, session)
      assert reason == {:virus, :not_active}

      ### Test 5: Missing payment information
      # TODO #244
    end
  end

  describe "handle_request/2" do
    test "starts collect" do
      %{
        local: %{gateway: gateway, entity: entity},
        session: session
      } = SessionSetup.create_local()

      {_, %{file: file1}} =
        SoftwareSetup.Virus.virus(
          entity_id: entity.entity_id,
          is_active?: true,
          real_file?: true
        )

      {_, %{file: file2}} =
        SoftwareSetup.Virus.virus(
          entity_id: entity.entity_id,
          is_active?: true,
          real_file?: true
        )

      bounce = NetworkSetup.Bounce.bounce!(entity_id: entity.entity_id)
      bank_account = BankSetup.account!(owner_id: entity.entity_id)

      params =
        %{
          "gateway_id" => gateway.server_id,
          "viruses" => [file1.file_id, file2.file_id],
          "bounce_id" => bounce.bounce_id,
          "atm_id" => bank_account.atm_id,
          "account_number" => bank_account.account_number,
          "wallet" => nil
        }

      request = RequestHelper.mock_request(unsafe: params)

      # There's nothing we can do with the response because it's async
      assert {:ok, _request} =
        RequestHelper.handle_request(VirusCollectRequest, request, session)

      # So let's make sure the processes were created
      processes = ProcessQuery.get_processes_on_server(gateway)

      process1 = Enum.find(processes, &(&1.src_file_id == file1.file_id))
      process2 = Enum.find(processes, &(&1.src_file_id == file2.file_id))

      assert process1.gateway_id == gateway.server_id
      assert process1.source_entity_id == entity.entity_id
      assert process1.src_connection_id
      assert process1.src_file_id == file1.file_id
      assert process1.bounce_id == bounce.bounce_id
      assert process1.tgt_atm_id == bank_account.atm_id
      assert process1.tgt_acc_number == bank_account.account_number
      refute process1.data.wallet

      assert process2.gateway_id == gateway.server_id
      assert process2.source_entity_id == entity.entity_id
      assert process2.src_connection_id
      assert process2.src_file_id == file2.file_id
      assert process2.bounce_id == bounce.bounce_id
      assert process2.tgt_atm_id == bank_account.atm_id
      assert process2.tgt_acc_number == bank_account.account_number
      refute process2.data.wallet

      TOPHelper.top_stop()
    end
  end
end
