defmodule WarnMultiErrorHandlingInObanJob.Common do
  @moduledoc """
  Nothing fancy, just a place to put common code
  """

  @doc "Simplify the code by opting into files that use Oban and alias Ecto"
  def continue_with_file?([{:__aliases__, _, _}, [do: {:__block__, [], header}]]) do
    using?(header, :Oban) and aliasing?(header, :Ecto)
  end

  def continue_with_file?(_), do: false

  @doc "inspect the method definitions"
  def walk({:|>, [line: _, column: _], args}, acc) do
    Enum.reduce(args, acc, &walk/2)
  end

  def walk(
        {{:., [line: _, column: _], [{:__aliases__, [line: _, column: _], [module]}, method]}, _,
         body},
        acc
      ) do
    acc =
      case {module, method} do
        {:Multi, :new} -> Map.put(acc, module, method)
        {:Repo, :transaction} -> Map.put(acc, module, method)
        _ -> acc
      end

    Enum.reduce(body, acc, &walk/2)
  end

  def walk(_, acc), do: acc

  @doc "Check if a module is being used"
  def using?(data, module), do: dig_for(data, :use, module)

  @doc "Check if a module is being aliased"
  def aliasing?(data, module), do: dig_for(data, :alias, module)

  # this HAS to be improvable
  defp dig_for(data, section, module) do
    data
    |> Enum.filter(fn item ->
      section == get_in(item, [Access.elem(0)])
    end)
    |> Enum.map(fn item ->
      item
      |> get_in([Access.elem(2)])
      |> get_in([Access.at(0)])
      |> get_in([Access.elem(2)])
      |> get_in([Access.at(0)])
    end)
    |> Enum.any?(&Kernel.==(&1, module))
  end
end
