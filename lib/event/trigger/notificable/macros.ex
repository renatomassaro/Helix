defmodule Helix.Event.Trigger.Notificable.Macros do

  defmacro __using__(_) do
    quote do

      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)

    end
  end

  defmacro __before_compile__(_) do
    quote do

      @class || raise "You must set a notification class with @class"
      @code || raise "You must set a notification code with @code"

      # TODO: Check compilation graph
      # NotificationCode.code_exists?(@class, @code)
      # || raise "Notification not found: #{inspect {@class, @code}}"

      @doc false
      def get_notification_info(_),
        do: {@class, @code}

      @doc false
      def extra_params(_),
        do: %{}

    end
  end
end
