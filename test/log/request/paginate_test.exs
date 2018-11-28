defmodule Helix.Log.Request.PaginateTest do

  use Helix.Test.Case.Integration

  alias Helix.Log.Request.Paginate, as: LogPaginateRequest

  alias Helix.Test.Session.Helper, as: SessionHelper
  alias Helix.Test.Webserver.Request.Helper, as: RequestHelper
  alias Helix.Test.Log.Helper, as: LogHelper

  @session SessionHelper.mock_session(:server_local)
  @default_total 20
  @max_total 100

  describe "check_params/2" do
    test "accepts when everything is OK" do
      log_id = LogHelper.id()

      url_params =
        %{
          "log_id" => to_string(log_id),
          "total" => 50
        }

      request = RequestHelper.mock_request(url_params: url_params)

      assert {:ok, request} = LogPaginateRequest.check_params(request, @session)

      assert request.params.log_id == log_id
      assert request.params.total == 50
    end

    test "adjusts `total` results when param is missing or invalid" do
      log_id = LogHelper.id()

      p_missing = %{"log_id" => to_string(log_id)}
      p_invalid0 = %{"log_id" => to_string(log_id), "total" => -10}
      p_invalid1 = %{"log_id" => to_string(log_id), "total" => "asdf"}
      p_max = %{"log_id" => to_string(log_id), "total" => 500_000}

      req_missing = RequestHelper.mock_request(url_params: p_missing)
      req_invalid0 = RequestHelper.mock_request(url_params: p_invalid0)
      req_invalid1 = RequestHelper.mock_request(url_params: p_invalid1)
      req_max = RequestHelper.mock_request(url_params: p_max)

      assert {:ok, req_missing} =
        LogPaginateRequest.check_params(req_missing, @session)
      assert {:ok, req_invalid0} =
        LogPaginateRequest.check_params(req_invalid0, @session)
      assert {:ok, req_invalid1} =
        LogPaginateRequest.check_params(req_invalid1, @session)
      assert {:ok, req_max} =
        LogPaginateRequest.check_params(req_max, @session)

      # Invalid requests will default to `@default_total` rows...
      assert req_missing.params.log_id == log_id
      assert req_missing.params.total == @default_total

      assert req_invalid0.params == req_missing.params
      assert req_invalid1.params == req_invalid0.params

      # Requests asking more than allowed will receive `@max_total` rows...
      assert req_max.params.total == @max_total
    end
  end
end
