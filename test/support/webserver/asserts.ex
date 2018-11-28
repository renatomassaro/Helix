defmodule Helix.Test.Webserver.Asserts do

  defmacro assert_status(conn, status),
    do: quote(do: assert unquote(conn).status == unquote(status))
  defmacro assert_halted(conn),
    do: quote(do: assert unquote(conn).halted)
  defmacro refute_halted(conn),
    do: quote(do: refute unquote(conn).halted)

  defmacro assert_resp_error(conn) do
    quote do
      assert Map.has_key?(unquote(conn).assigns.helix_response, :error)
    end
  end

  defmacro assert_resp_error(conn, reason, status \\ quote(do: 403)) do
    quote do
      assert_resp_error unquote(conn)
      assert unquote(conn).assigns.helix_response.error.reason ==
        unquote(reason)
      assert_status unquote(conn), unquote(status)
    end
  end

  defmacro assert_empty_response(conn, status \\ quote(do: 200)) do
    quote do
      assert Enum.empty?(get_response(unquote(conn)))
      assert_status unquote(conn), unquote(status)
    end
  end
end
