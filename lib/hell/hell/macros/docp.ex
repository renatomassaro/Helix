defmodule HELL.Macros.Docp do
  @moduledoc """
  Custom module because this macro is used extensively throughout the code and
  importing it from elsewhere may drag unwanted/unneeded modules.
  """

  @doc """
  This macro exists solely to allow the use of heredocs to document private
  functions without Elixir raising a warning.

  I KNOW.

  ## Example
    docp \"\"\"
    Does something
    \"\"\"
    defp private_fun(),
      do: :something
  """
  defmacro docp(_),
    do: :ok
end
