defmodule Helix.Test.Process do

  use Helix.Process

  process FakeFileTransfer do

    alias HELL.TestHelper.Random

    process_struct [:file_id]

    @type creation_params :: term
    @type executable_meta :: term

    def new do
      %__MODULE__{
        file_id: Random.number()
      }
    end

    def new(%{file_id: file_id}, _) do
      %__MODULE__{
        file_id: file_id
      }
    end

    processable do

      def on_complete(_process, _data, _reason),
        do: {:delete, []}
    end

    resourceable do

      alias Helix.Test.Network.Helper, as: NetworkHelper

      @internet_id NetworkHelper.internet_id()

      @type factors :: term

      get_factors(_) do
        :noop
      end

      def network_id(_, _),
        do: @internet_id

      def dlk(_, %{type: :download}),
        do: 100
      def dlk(_, _),
        do: 0

      def ulk(_, %{type: :upload}),
        do: 100
      def ulk(_, _),
        do: 0

      def dynamic(%{type: :download}),
        do: [:dlk]
      def dynamic(%{type: :upload}),
        do: [:ulk]
    end

    executable do
    end
  end

  process FakeDefaultProcess do

    process_struct [:foo]

    @type creation_params :: term
    @type executable_meta :: term

    def new do
      %__MODULE__{
        foo: :bar
      }
    end

    processable do

      def on_complete(_process, _data, _reason),
        do: {:delete, []}
    end

    resourceable do

      @type factors :: term

      get_factors(_) do
        :noop
      end

      def cpu(_, _),
        do: 5000

      def dynamic(_),
        do: [:cpu]
    end

    executable do
    end
  end
end
