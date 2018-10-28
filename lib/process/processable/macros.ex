defmodule Helix.Process.Processable.Macros do

  defmacro __using__(_) do
    quote do

      Module.register_attribute(__MODULE__, :signals, accumulate: true)

      @on_definition unquote(__MODULE__)
      @before_compile unquote(__MODULE__)

    end
  end

  defmacro __before_compile__(_) do
    quote do

      unless :on_complete in @signals,
        do: raise "Missing mandatory `on_complete` signal handler"

      def signals_handled,
        do: @signals

    end
  end

  def __on_definition__(env, _kind, name, _args, _guards, _body),
    do: Module.put_attribute(env.module, :signals, name)
end
