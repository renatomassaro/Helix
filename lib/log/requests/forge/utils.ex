defmodule Helix.Log.Requests.Forge.Utils do

  alias Helix.Webserver.Request.Utils, as: RequestUtils
  alias Helix.Log.Model.Log
  alias Helix.Log.Model.LogType

  @spec cast_log_info(String.t, map) ::
    {:ok, Log.info}
    | {:error, :bad_log_type | :bad_log_data}
  def cast_log_info(unsafe_log_type, unsafe_log_data) do
    with \
      {:ok, log_type} <- RequestUtils.cast_existing_atom(unsafe_log_type),
      true <- LogType.exists?(log_type) || {:error, :log_type},
      {:ok, log_data} <- LogType.parse(log_type, unsafe_log_data)
    do
      {:ok, {log_type, log_data}}
    else
      {:error, :atom_not_found} ->
        {:error, :bad_log_type}

      {:error, :log_type} ->
        {:error, :bad_log_type}

      :error ->
        {:error, :bad_log_data}
    end
  end
end
