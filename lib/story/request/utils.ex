defmodule Helix.Story.Request.Utils do

  @doc """
  Makes sure that whatever contact the player is trying to use, exists on the
  system. It doesn't actually verify whether the contact is valid (one could use
  "error" or any atom as a contact), but that will be validated later.
  """
  def cast_contact(contact_id) do
    try do
      {:ok, String.to_existing_atom(contact_id)}
    rescue
      _ ->
        {:error, :bad_contact}
    end
  end
end
