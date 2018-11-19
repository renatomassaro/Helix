defmodule Helix.Log.Model.Log do

  use Ecto.Schema
  use HELL.ID, field: :log_id

  import Ecto.Changeset
  import HELL.Ecto.Macros

  alias Ecto.Changeset
  alias Helix.Server.Model.Server
  alias Helix.Log.Model.LogType
  alias Helix.Log.Model.Revision
  alias __MODULE__

  @type t ::
    %__MODULE__{
      log_id: id,
      revision_id: Revision.id,
      server_id: Server.id,
      creation_time: DateTime.t,
      revision: nil | Revision.t
    }

  @type changeset :: %Changeset{data: %__MODULE__{}}

  @type type :: LogType.type
  @type data :: LogType.data
  @type info :: {type, data}

  @type creation_params :: %{server_id: Server.id}

  @creation_fields [:server_id]
  @required_fields [:server_id, :revision_id, :creation_time, :log_id]

  @derive {Poison.Encoder, only: [:log_id, :revision_id, :server_id, :revision]}
  @primary_key false
  schema "logs" do
    field :log_id, id(),
      primary_key: true

    field :revision_id, :integer
    field :server_id, id(:server)

    # Stores the exact moment the log was created. This value is immutable! Even
    # if several revisions occurred at a later time, the `creation_time` of the
    # log object remains unchanged.
    field :creation_time, :utc_datetime

    field :revision, :map,
      virtual: true,
      default: nil

    has_many :revisions, Revision,
      foreign_key: :log_id,
      references: :log_id,
      on_delete: :delete_all,
      on_replace: :delete
  end

  @spec create_changeset(creation_params, Revision.creation_params) ::
    changeset
  def create_changeset(params, revision_params) do
    log_id =
      params
      |> build_heritage()
      |> ID.generate(:log)

    revision_changeset = Revision.create_changeset(log_id, 1, revision_params)
    revision = apply_changes(revision_changeset)

    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> put_change(:creation_time, revision.creation_time)
    |> put_change(:log_id, log_id)
    |> put_change(:revision_id, 1)
    |> put_assoc(:revisions, [revision_changeset])
    |> put_change(:revision, revision)
    |> validate_required(@required_fields)
  end

  @spec add_revision(t, Revision.creation_params) ::
    {changeset, Revision.changeset}
  def add_revision(log = %Log{}, revision_params) do
    next_revision_id = log.revision_id + 1

    revision_changeset =
      Revision.create_changeset(log.log_id, next_revision_id, revision_params)

    log_changeset =
      log
      |> change()
      |> put_change(:revision_id, next_revision_id)
      |> put_change(:revision, apply_changes(revision_changeset))

    {log_changeset, revision_changeset}
  end

  @spec recover_revision(Log.t, previous_revision :: Revision.t | nil) ::
    {:original, :natural | :artificial}
    | {:recover, changeset}
  @doc """
  Based on the previous revision (which may not exist) and the current revision,
  figure out whether we are dealing with a natural or artificial log, and
  whether it should be recovered, destroyed or kept as is.

  In case it's not clear:

  If a previous revision exists on the stack, it doesn't matter if the log is
  artificial or natural, we should recover it anyway.

  If a previous revision does not exist, we look at the current revision (which
  is, necessarily, the original one). If it has a `forger_version`, then the
  first revision was created through a `LogForgeProcess`, and it's an artificial
  log. Otherwise it's natural.
  """
  def recover_revision(%Log{revision: %{forge_version: nil}}, nil),
    do: {:original, :natural}
  def recover_revision(_, nil),
    do: {:original, :artificial}
  def recover_revision(log = %Log{}, previous_revision = %Revision{}) do
    changeset =
      log
      |> change()
      |> put_change(:revision_id, previous_revision.revision_id)
      |> put_change(:revision, previous_revision)

    {:recover, changeset}
  end

  @spec is_artificial?(t) ::
    boolean
  @doc """
  Returns whether the log is artificial or not.
  """
  def is_artificial?(%Log{revision: %{forge_version: nil}}),
    do: false
  def is_artificial?(%Log{}),
    do: true

  @spec count_extra_revisions(t) ::
    non_neg_integer
  @doc """
  Counts how many revisions are there on top of the original one.

  The "original" revision for an artificial log is considered to be an empty
  log, so when an artificial log is at `revision_id=1`, there still is one extra
  revision on top of the original.

  On the other hand, natural longs at `revision_id=1` are already at the
  original one.
  """
  def count_extra_revisions(log = %Log{}) do
    if is_artificial?(log) do
      log.revision_id
    else
      log.revision_id - 1
    end
  end

  @spec build_heritage(creation_params) ::
    Helix.ID.heritage
  defp build_heritage(params),
    do: %{parent: params.server_id}

  query do

    alias Helix.Server.Model.Server
    alias Helix.Log.Model.Log
    alias Helix.Log.Model.Revision

    @spec by_id(Queryable.t, Log.id) ::
      Queryable.t
    def by_id(query \\ Log, log_id),
      do: where(query, [l], l.log_id == ^log_id)

    @spec by_server(Queryable.t, Server.id) ::
      Queryable.t
    def by_server(query \\ Log, server_id),
      do: where(query, [l], l.server_id == ^server_id)

    @spec include_revision(Queryable.t) ::
      Queryable.t
    @doc """
    Joins the Log.Revision table and includes the revision data with the result.
    """
    def include_revision(query) do
      from l in query,
        inner_join: lr in Revision,
        on: l.log_id == lr.log_id and l.revision_id == lr.revision_id,
        select: %Log{l | revision: lr}
    end

    @spec paginate_after_log(Queryable.t, Log.id) ::
      Queryable.t
    @doc """
    Returns only logs that are older than the given `log_id`.
    """
    def paginate_after_log(query, log_id),
      do: where(query, [l], l.log_id > ^log_id)

    @spec only(Queryable.t, pos_integer) ::
      Queryable.t
    @doc """
    Limits the resulting set to `total` rows.
    """
    def only(query, total),
      do: limit(query, ^total)

    @spec lock_for_update(Queryable.t) ::
      Queryable.t
    def lock_for_update(query),
      do: lock(query, "FOR UPDATE")
  end

  order do

    @spec by_id(Queryable.t) ::
      Queryable.t
    @doc """
    Orders the resulting set by the log id (newest first).
    """
    def by_id(query),
      do: order_by(query, [l], desc: l.log_id)
  end
end
