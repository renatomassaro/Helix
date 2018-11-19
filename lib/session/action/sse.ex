defmodule Helix.Session.Action.SSE do

  alias Helix.Session.Internal.SSE, as: SSEInternal

  def bulk_insert_in_queue(one) do
    SSEInternal.bulk_insert_in_queue(one)
  end

  def bulk_remove_from_queue(message_id_list) do
    SSEInternal.bulk_remove_from_queue(message_id_list)
  end
end
