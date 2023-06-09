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

  import WarnMultiErrorHandlingInObanJob.Common

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
      %{Multi: :new, Repo: :transaction, error: _} ->
        issues

      %{Multi: :new, Repo: :transaction} ->
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
