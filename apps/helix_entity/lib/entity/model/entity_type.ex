defmodule Helix.Entity.Model.EntityType do

  use Ecto.Schema

  @type name :: String.t
  @type t :: %__MODULE__{
    entity_type: name
  }

  @primary_key false
  schema "entity_types" do
    field :entity_type, :string,
      primary_key: true
  end

  @doc false
  def possible_types do
    ~w/account clan npc/
  end

  @doc false
  def type_implementations do
    %{
      "account" => Helix.Account.Model.Account,
      "clan" => Helix.Clan.Model.Clan,
      "npc" => Helix.NPC.Model.NPC
    }
  end
end
