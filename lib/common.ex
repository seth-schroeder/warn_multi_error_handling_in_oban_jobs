defmodule WarnMultiErrorHandlingInObanJob.Common do
  @moduledoc """
  Nothing fancy, just a place to put common code
  """

  @doc "Simplify the code by opting into files that use Oban and alias Ecto"
  def continue_with_file?([{:__aliases__, _, _}, [do: {:__block__, [], header}]]) do
    using?(header, :Oban) and aliasing?(header, :Ecto)
  end

  def continue_with_file?(_), do: false

  @doc "Walk through the method bodies"
  def walk({:|>, [line: _, column: _], args}, acc) do
    Enum.reduce(args, acc, &walk/2)
  end

  def walk({{:., _, [{:__aliases__, _, [module]}, method]}, _, body}, acc) do
    acc =
      case {module, method} do
        {:Multi, :new} -> Map.put(acc, module, method)
        {:Repo, :transaction} -> Map.put(acc, module, method)
        _ -> acc
      end

    Enum.reduce(body, acc, &walk/2)
  end

  def walk({:case, [line: _line, column: _column], [[do: clauses]]}, acc) do
    Enum.reduce(clauses, acc, &look_at_error_handling/2)
  end

  def walk(_, acc), do: acc

  def look_at_error_handling({:->, _, [[ok: _], _]}, acc), do: acc

  def look_at_error_handling({:->, _, [[{:{}, _, [:error, _, _, _]}], {:error, message}]}, acc) do
    Map.put(acc, :error, message)
  end

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
