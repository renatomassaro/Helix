defmodule Helix.Process.Viewable do

  alias Helix.Process.Model.Process

  @default_viewable Helix.Process.Viewable.Default

  def render(process = %Process{}) do
    viewable = get_viewable_hembed(process)

    base = call_viewable_implementation(process, viewable, :render)
    data = call_viewable_implementation(process, viewable, :render_data)

    Map.merge(base, %{data: data})
  end

  defp call_viewable_implementation(process, viewable, method) do
    try do
      apply(viewable, method, [process])
    rescue
      _ ->
        apply(@default_viewable, method, [process])
    end
  end

  defp get_viewable_hembed(%Process{data: process_data}),
    do: get_viewable_hembed(process_data)
  defp get_viewable_hembed(process),
    do: Module.concat(process.__struct__, Viewable)
end
