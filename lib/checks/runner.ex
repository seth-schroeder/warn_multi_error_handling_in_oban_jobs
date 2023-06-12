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
    if in_header?(body, :use, :Oban) do
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

  defp walk({:|>, [line: _, column: _], args}, acc) do
    Enum.reduce(args, acc, &walk/2)
  end

  defp walk({{:., _, [{:__aliases__, _, module}, method]}, _, body}, acc) do
    acc =
      case {module, method} do
        {[:Ecto, :Multi], :new} -> Map.put(acc, module, method)
        {[:Multi], :new} -> Map.put(acc, [:Ecto | module], method)
        {[:Repo], :transaction} -> Map.put(acc, module, method)
        _ -> acc
      end

    Enum.reduce(body, acc, &walk/2)
  end

  defp walk({:case, [line: _line, column: _column], [[do: clauses]]}, acc) do
    Enum.reduce(clauses, acc, &look_at_error_handling/2)
  end

  # NOTE: special exception for commented out code being checked in -- I have deleted this waaaaaay too many times now.
  #
  # defp walk(zut_alors, acc) do
  #   dbg(zut_alors)
  #   acc
  # end

  defp walk(_, acc), do: acc

  defp look_at_error_handling({:->, _, [[ok: _], _]}, acc), do: acc

  defp look_at_error_handling({:->, _, [[{:{}, _, [:error, _, _, _]}], {:error, message}]}, acc) do
    Map.put(acc, :error, message)
  end

  # This HAS to be improvable. It used to have more than one caller.
  defp in_header?([{:__aliases__, _, _}, [do: {:__block__, [], header}]], section, module) do
    header
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

  defp in_header?(_, _, _), do: false

  defp issues_for_function_definition([_, [do: body]], line, issues, _, issue_meta) do
    case walk(body, %{}) do
      %{[:Ecto, :Multi] => :new, [:Repo] => :transaction, error: _} ->
        issues

      %{[:Ecto, :Multi] => :new, [:Repo] => :transaction} ->
        [issue_for("potential error handling concern", line, issue_meta) | issues]

      _ ->
        issues
    end
  end

  defp issue_for(trigger, line_no, issue_meta) do
    format_issue(
      issue_meta,
      message: "Potential false negative on Multi error handling in an Oban job",
      trigger: "@#{trigger}",
      line_no: line_no
    )
  end
end
