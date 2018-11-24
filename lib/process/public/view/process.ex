defmodule Helix.Process.Public.View.Process do
  @moduledoc """
  `ProcessView` is a wrapper to the `ProcessViewable` protocol. Public methods
  interested on rendering a process (and as such using `ProcessViewable`) should
  use `ProcessView.render/4` instead.
  """

  alias HELL.HETypes
  alias Helix.Entity.Model.Entity
  alias Helix.Network.Model.Network
  alias Helix.Process.Model.Process
  alias Helix.Process.Viewable

  @type process ::
    %{
      process_id: String.t,
      type: String.t,
      state: String.t,
      progress: progress | nil,
      priority: 0..5,
      usage: resources,
      source_file: file,
      target_file: file,
      origin_ip: Network.ip,
      target_ip: String.t,
      source_connection_id: String.t | nil,
      target_connection_id: String.t | nil,
      network_id: String.t
    }

  @type file ::
    %{
      id: String.t | nil,
      name: String.t,
      version: float | nil
    }
    | nil

  @type progress ::
    %{
      percentage: float | nil,
      completion_date: HETypes.client_timestamp | nil,
      creation_date: HETypes.client_timestamp
    }

  @type resources ::
    %{
      cpu: resource_usage,
      ram: resource_usage,
      ulk: resource_usage,
      dlk: resource_usage
    }

  @typep resource_usage ::
    %{
      percentage: float,
      absolute: non_neg_integer
    }

  @spec render(Process.t, Entity.id) ::
    process
    | nil
  def render(process = %Process{source_entity_id: entity_id}, entity_id),
    do: Viewable.render(process)
  def render(_process, _entity_id),
    do: nil
end
