defmodule Helix.Event.Trigger.Notificable do

  import HELL.Macros.Docp

  alias Hevent.Trigger

  alias Helix.Account.Model.Account
  alias Helix.Entity.Model.Entity
  alias Helix.Server.Model.Server
  alias Helix.Notification.Action.Notification, as: NotificationAction
  alias Helix.Notification.Model.Code, as: NotificationCode
  alias Helix.Notification.Model.Notification
  alias Helix.Event

  @type whom_to_notify ::
    Account.id
    | Entity.id
    | %{account_id: Account.id, server_id: Server.id}
    | %{account_id: Entity.id, server_id: Server.id}
    | Server.id

  @trigger Notificable

  @spec flow(Event.t) ::
    term
  def flow(event) do
    {class, code} = Trigger.get_data(event, :get_notification_info, @trigger)
    extra_params = Trigger.get_data(event, :extra_params, @trigger)
    whom_to_notify = Trigger.get_data(event, :whom_to_notify, @trigger)
    data = NotificationCode.generate_data(class, code, event)

    class
    |> get_target_ids(whom_to_notify)
    |> Enum.map(fn id_map ->
      with \
        {:ok, _, event} <-
          NotificationAction.add_notification(
            class, code, data, id_map, extra_params
          )
      do
        Event.emit(event)
      end
    end)
  end

  @spec get_target_ids(Notification.class, whom_to_notify) ::
    [Notification.id_map]
  docp """
  Returns the list of players ("targets") that shall receive the notification.

  This list was passed through `Notification.get_id_map/2` and it contains all
  id information the notification needs to be stored correctly.

  Notice that the param sent to `get_id_map/2` isn't necessarily the same data
  returned by `Notificable.whom_to_notify/1`; it may be altered.
  """
  defp get_target_ids(_, :no_one),
    do: []
  defp get_target_ids(:account, account_id),
    do: [Notification.get_id_map(:account, account_id)]
  defp get_target_ids(:server, %{account_id: account_id, server_id: server_id}),
    do: [Notification.get_id_map(:server, {server_id, account_id})]
end
