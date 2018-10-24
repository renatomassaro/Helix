defmodule Helix.Event.Trigger.Publishable.Macros do

  defmacro __using__(_) do
    quote do

      import unquote(__MODULE__)

    end
  end

  defmacro event_name(name) do
    quote do

      @doc false
      def event_name(_),
        do: to_string(unquote(name))

    end
  end
end
