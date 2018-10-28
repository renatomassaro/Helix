defmodule Helix.Process.Executable.Formatter do

  alias HELL.Utils
  alias Helix.Log.Model.Log
  alias Helix.Server.Model.Server
  alias Helix.Software.Model.File
  alias Helix.Universe.Bank.Model.BankAccount
  alias Helix.Process.Model.Process

  def format(:custom, result) when is_map(result),
    do: result

  def format(:resources, result) when is_map(result),
    do: result

  def format(:source_file, %File{file_id: file_id}),
    do: %{src_file_id: file_id}
  def format(:source_file, file_id = %File.ID{}),
    do: %{src_file_id: file_id}
  def format(:source_file, nil),
    do: %{src_file_id: nil}

  def format(:target_file, %File{file_id: file_id}),
    do: %{tgt_file_id: file_id}
  def format(:target_file, file_id = %File.ID{}),
    do: %{tgt_file_id: file_id}
  def format(:target_file, nil),
    do: %{tgt_file_id: nil}

  def format(:source_connection, result),
    do: result

  def format(:target_connection, result),
    do: result

  def format(:target_process, %Process{process_id: process_id}),
    do: %{tgt_process_id: process_id}
  def format(:target_process, process_id = %Process.ID{}),
    do: %{tgt_process_id: process_id}
  def format(:target_process, nil),
    do: %{tgt_process_id: nil}

  def format(:target_log, %Log{log_id: log_id}),
    do: %{tgt_log_id: log_id}
  def format(:target_log, log_id = %Log.ID{}),
    do: %{tgt_log_id: log_id}
  def format(:target_log, nil),
    do: %{tgt_log_id: nil}

  def format(:source_bank_account, result),
    do: format_bank_account(result, :src)

  def format(:target_bank_account, result),
    do: format_bank_account(result, :tgt)

  @spec format_bank_account(BankAccount.t | tuple | nil, prefix :: atom) ::
    {Server.id, BankAccount.account}
    | {nil, nil}
  defp format_bank_account(%_{atm_id: atm_id, account_number: number}, prefix),
    do: format_bank_account({atm_id, number}, prefix)
  defp format_bank_account(nil, _),
    do: {nil, nil}
  defp format_bank_account({atm_id, account_number}, prefix) do
    %{}
    |> Map.put(Utils.concat_atom(prefix, :_atm_id), atm_id)
    |> Map.put(Utils.concat_atom(prefix, :_acc_number), account_number)
  end
end
