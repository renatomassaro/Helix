defmodule Helix.Process.Resourceable do
  @moduledoc """
  # Resourceable

  `Process.Resourceable` is a DSL to calculate how many resources, for each type
  of hardware resource, a process should use. This usage involves:

  - Figuring out the process' objective, the total amount of work a process
    should perform before being deemed completed.
  - How many resources the project should allocate statically, whether it's
    paused or running.
  - What resources can be dynamically allocated, according to the server's total
    available resources.

  It builds upon `Helix.Factor` and its `FactorClient` API, which will
  efficiently retrieve all data you need to figure out the correct resource
  usage for that process.

  Once you have the factors, each resource will be called:

  ### Objective

  - cpu (Processor usage)
  - ram (Memory usage)
  - dlk (Downlink usage)
  - ulk (Uplink usage)

  You must specify at least one resource. You can specify them with the namesake
  methods `cpu`, `ram`, `dlk` and `ulk`.

  These resource blocks should return either `nil` or an integer that represents
  how much the process should work - its objectives.

  ### Allocation:

  - static(params, factors) -- Specifies static resource allocation 
  - dynamic(params, factors) -- List of dynamically allocated resources

  The resource blocks argument is the `params` specified at Process's top-level
  `objective/n`. On top of that, within the block scope you have access to the
  `f` variable, which is a map containing all factors returned from the
  `get_factors` function you defined beforehand.

  # Usage example

  ```
  resourceable do

    @type params :: %{type: :download | :upload}

    @type factors :: %{size: integer}

    # Gets all the data I need
    get_factors(params) do
      factor Helix.Software.Factor.File, params, only: :size
    end

    # Specifies the Downlink usage if it's a download
    def dlk(f, %{type: :download}),
      do: f.file.size  # Variable `f` contains the results of `get_factors`
    def dlk(_, %{type: :upload}),
      do: 0

    # Specifies the Uplink usage if it's an uplink
    def ulk(f, %{type: :upload}),
      do: f.file.size
    def ulk(_, %{type: :download}),
      do: 0

    # Static allocation

    def static,
      do: %{paused: %{ram: 50}}

    # Dynamic allocation
    def dynamic(%{type: :download}),
      do: [:dlk]
    def dynamic(%{type: :upload}),
      do: [:ulk]
  end
  ```

  ### Safety fallback

  When pattern match params within `Process.Objective`, like the example above,
  you are required to match against all possible input values.

  While putting a `dlk(_)` would suffice, it's better to be explicit on which
  fallbacks should return a `nil` usage, like we do on the example above.

  This way, a small typo on the pattern match, like `dlk(%{type: :downlaod})`,
  would blow up, instead of returning a silent bug that would allow players to
  download files instantaneously :-).
  """

  @type resource_usage :: number

  @empty_resource 0

  def get_resources(process, params) do
    resourceable = get_resourceable_hembed(process)
    callbacks = get_implemented_callbacks(resourceable)

    factors = apply(resourceable, :get_factors, [params])
    args = [factors, params]

    %{
      objective: objective(resourceable, callbacks, args),
      static: static(resourceable, callbacks, args),
      l_dynamic: l_dynamic(resourceable, callbacks, args),
      r_dynamic: r_dynamic(resourceable, callbacks, args)
    }
  end

  defp objective(resourceable, callbacks, args) do
    network_id = get_network_id(resourceable, callbacks, args)

    %{
      cpu: objective_cpu(resourceable, callbacks, args),
      ram: objective_ram(resourceable, callbacks, args),
      dlk: objective_dlk(resourceable, callbacks, args, network_id),
      ulk: objective_ulk(resourceable, callbacks, args, network_id)
    }
    |> Enum.reject(fn {_, total} -> total == %{} end)
    |> Enum.reject(fn {_, total} -> total == 0 end)
    |> Enum.into(%{})
  end

  defp static(resourceable, %{static: 0}, _),
    do: apply(resourceable, :static, [])
  defp static(resourceable, %{static: 1}, [_, params]),
    do: apply(resourceable, :static, [params])
  defp static(resourceable, %{static: _}, args),
    do: apply(resourceable, :static, args)
  defp static(_, _, _),
    do: %{}

  defp l_dynamic(resourceable, %{dynamic: 0}, _),
    do: apply(resourceable, :dynamic, [])
  defp l_dynamic(resourceable, %{dynamic: 1}, [_, params]),
    do: apply(resourceable, :dynamic, [params])
  defp l_dynamic(resourceable, %{dynamic: 2}, args),
    do: apply(resourceable, :dynamic, args)
  defp l_dynamic(_, _, _),
    do: []

  defp r_dynamic(resourceable, %{r_dynamic: 0}, _),
    do: apply(resourceable, :r_dynamic, [])
  defp r_dynamic(resourceable, %{r_dynamic: 1}, [_, params]),
    do: apply(resourceable, :r_dynamic, [params])
  defp r_dynamic(resourceable, %{r_dynamic: _}, args),
    do: apply(resourceable, :r_dynamic, args)
  defp r_dynamic(_, _, _),
    do: []

  defp get_network_id(resourceable, %{network_id: 0}, _),
    do: apply(resourceable, :network_id, [])
  defp get_network_id(resourceable, %{network_id: 1}, [_, params]),
    do: apply(resourceable, :network_id, [params])
  defp get_network_id(resourceable, %{network_id: 2}, args),
    do: apply(resourceable, :network_id, args)
  defp get_network_id(_, _, _),
    do: nil

  defp objective_cpu(resourceable, %{cpu: _}, args),
    do: apply(resourceable, :cpu, args)
  defp objective_cpu(_, _, _),
    do: @empty_resource

  defp objective_ram(resourceable, %{ram: _}, args),
    do: apply(resourceable, :ram, args)
  defp objective_ram(_, _, _),
    do: @empty_resource

  defp objective_dlk(resourceable, %{dlk: _}, args, network_id) do
    resourceable
    |> apply(:dlk, args)
    |> add_network_to_resource(network_id)
  end
  defp objective_dlk(_, _, _, _),
    do: @empty_resource

  defp objective_ulk(resourceable, %{ulk: _}, args, network_id) do
    resourceable
    |> apply(:ulk, args)
    |> add_network_to_resource(network_id)
  end
  defp objective_ulk(_, _, _, _),
    do: @empty_resource

  defp add_network_to_resource(_, nil),
    do: @empty_resource
  defp add_network_to_resource(resource, network_id) do
    %{}
    |> Map.put(network_id, resource)
    |> Enum.filter(fn {_net_id, val} ->
      is_number(val) && val > 0
    end)
    |> Map.new()
  end

  defp get_resourceable_hembed(process),
    do: Module.concat(process, Resourceable)

  defp get_implemented_callbacks(resourceable) do
    :functions
    |> resourceable.__info__()
    |> Enum.into(%{})
  end
end
