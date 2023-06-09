defmodule WarnMultiErrorHandlingInObanJob.Checks.Tracer do
  @moduledoc "Helpful for development, just dumps AST to the screen"
  import WarnMultiErrorHandlingInObanJob.Common
  use Credo.Check

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

  defp traverse(ast, issues, _, _) do
    # credo:disable-for-next-line Credo.Check.Warning.Dbg
    dbg(ast)
    {ast, issues}
  end
end
