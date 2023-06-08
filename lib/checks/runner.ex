defmodule WarnMultiErrorHandlingInObanJob.Checks.Runner do
  @moduledoc """
  Repo.transaction will return a 4 tuple when an error occurs inside a Multi.
  Verify that errors are being mapped to a 2 tuple that Oban will interpret as expected.

  iex(14)> [warning] Expected Elixir.MyApp.MultiFailure.perform/1 to return:
  - `:ok`
  - `:discard`
  - `{:ok, value}`
  - `{:error, reason}`,
  - `{:cancel, reason}`
  - `{:discard, reason}`
  - `{:snooze, seconds}`
  Instead received:
  {:error, :alas, :poor_yorick, %{}}

  The job will be considered a success.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      Repo.transaction will return a 4 tuple when an error occurs inside a Multi.
      Verify that errors are being mapped to a 2 tuple that Oban will interpret as expected.

      iex(14)> [warning] Expected Elixir.MyApp.MultiFailure.perform/1 to return:
      - `:ok`
      - `:discard`
      - `{:ok, value}`
      - `{:error, reason}`,
      - `{:cancel, reason}`
      - `{:discard, reason}`
      - `{:snooze, seconds}`
      Instead received:
      {:error, :alas, :poor_yorick, %{}}

      The job will be considered a success.
      """
    ]

  def run(%SourceFile{} = source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse(&1, &2, nil, issue_meta))
  end

  # Simplify the code by looking only at relevant files
  defp traverse({:defmodule, _, body} = ast, issues, _, _) do
    if continue_with_file?(body) do
      {ast, issues}
    else
      {{}, issues}
    end
  end

  defp traverse({:def, [line: line, column: _column], heads} = ast, issues, params, issue_meta) do
    {ast, issues_for_function_definition(heads, line, issues, params, issue_meta)}
  end

  defp traverse({:defp, [line: line, column: _column], heads} = ast, issues, params, issue_meta) do
    {ast, issues_for_function_definition(heads, line, issues, params, issue_meta)}
  end

  # Everything else passes through
  defp traverse(ast, issues, _, _) do
    {ast, issues}
  end

  defp issues_for_function_definition([_, [do: body]], line, issues, _, issue_meta) do
    case walk(body, %{}) do
      %{Multi: :new, Repo: :transaction} ->
        [issue_for("potential error handling concern", line, issue_meta) | issues]

      _ ->
        issues
    end
  end

  defp continue_with_file?([{:__aliases__, _, _}, [do: {:__block__, [], header}]]) do
    using?(header, :Oban) and aliasing?(header, :Ecto)
  end

  defp continue_with_file?(_), do: false

  # Recurse into piped method calls
  defp walk({:|>, [line: _, column: _], args}, acc) do
    Enum.reduce(args, acc, &walk/2)
  end

  # Look at the method calls
  defp walk(
         {{:., [line: _, column: _], [{:__aliases__, [line: _, column: _], [module]}, method]}, _,
          _},
         acc
       ) do
    case {module, method} do
      {:Multi, :new} -> Map.put(acc, module, method)
      {:Repo, :transaction} -> Map.put(acc, module, method)
      _ -> acc
    end
  end

  # Pass through
  defp walk(_, acc), do: acc

  defp issue_for(trigger, line_no, issue_meta) do
    format_issue(
      issue_meta,
      message: "Potential false negative on Multi error handling in an Oban job",
      trigger: "@#{trigger}",
      line_no: line_no
    )
  end

  defp using?(data, module), do: dig_for(data, :use, module)
  defp aliasing?(data, module), do: dig_for(data, :alias, module)

  defp dig_for(nil, _, _), do: false

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
