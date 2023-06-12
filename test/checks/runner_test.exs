defmodule WarnMultiErrorHandlingInObanJob.Checks.RunnerTest do
  use Credo.Test.Case

  alias WarnMultiErrorHandlingInObanJob.Checks.Runner

  describe "true negatives" do
    test "explicit mapping to a two tuple" do
      """
      def perform(%{}) do
        Multi.new()
        |> Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
        |> case do
           {:ok, _} -> :ok
           {:error, _, _, _} -> {:error, "we knew him well"}
           end
      end
      """
      |> sample_code()
      |> to_source_file()
      |> run_check(Runner)
      |> refute_issues()
    end

    test "explicit mapping to a two tuple, not aliased" do
      """
      def perform(%{}) do
        Ecto.Multi.new()
        |> Ecto.Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
        |> case do
           {:ok, _} -> :ok
           {:error, _, _, _} -> {:error, "we knew him well"}
           end
      end
      """
      |> sample_code(alias: false)
      |> to_source_file()
      |> run_check(Runner)
      |> refute_issues()
    end

    test "explicit mapping to a two tuple, not free" do
      """
      def perform(%{}) do
        Ecto.Multi.new()
        |> Ecto.Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
        |> case do
           {:ok, _} -> :ok
           {:error, _, _, _} -> {:error, "we knew him well"}
           end
      end
      """
      |> sample_code(free: false)
      |> to_source_file()
      |> run_check(Runner)
      |> refute_issues()
    end

    test "methods in the worker other than .perform" do
      """
      def perform(%{}) do
        whether_tis_nobler()
      end

      defp whether_tis_nobler() do
        Multi.new()
        |> Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
        |> case do
           {:ok, _} -> :ok
           {:error, _, _, _} -> {:error, "we knew him well"}
           end
      end
      """
      |> sample_code()
      |> to_source_file()
      |> run_check(Runner)
      |> refute_issues()
    end

    test "sanity check" do
      """
      def perform(%{}) do
        {:ok, Enum.count([])}
      end
      """
      |> sample_code()
      |> to_source_file()
      |> run_check(Runner)
      |> refute_issues()
    end

    test "ignores non-Oban files" do
      """
      def perform(%{}) do
        Multi.new()
        |> Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
      end
      """
      |> sample_code()
      |> String.replace(~r/Oban/, "Goban")
      |> to_source_file()
      |> run_check(Runner)
      |> refute_issues()
    end
  end

  describe "true positives" do
    test "pipe chain returning a four tuple" do
      """
      def perform(%{}) do
      Multi.new()
      |> Multi.error(:alas, :poor_yorick)
      |> Repo.transaction()
      end
      """
      |> sample_code()
      |> to_source_file()
      |> run_check(Runner)
      |> assert_issue()
    end

    test "Does not require aliasing Multi" do
      """
      def perform(%{}) do
        Ecto.Multi.new()
        |> Ecto.Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
      end
      """
      |> sample_code(alias: false)
      |> to_source_file()
      |> run_check(Runner)
      |> assert_issue()
    end

    test "Does not require free Oban" do
      """
      def perform(%{}) do
        Ecto.Multi.new()
        |> Ecto.Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
      end
      """
      |> sample_code(free: false)
      |> to_source_file()
      |> run_check(Runner)
      |> assert_issue()
    end

    test "nested calls returning a four tuple" do
      """
      def perform(%{}) do
        Repo.transaction(Multi.error(Multi.new(), :alas, :poor_yorick))
      end
      """
      |> sample_code()
      |> to_source_file()
      |> run_check(Runner)
      |> assert_issue()
    end

    # This is a little misleading. This check does not look to see if `perform` calls `whether_tis_nobler`.
    # This just leans on the nervous side that such a risky method exists in the module.
    test "delegated calls returning a four tuple" do
      """
      def perform(%{}) do
        whether_tis_nobler()
      end

      defp whether_tis_nobler() do
        Multi.new()
        |> Multi.error(:alas, :poor_yorick)
        |> Repo.transaction()
      end
      """
      |> sample_code()
      |> to_source_file()
      |> run_check(Runner)
      |> assert_issue()
    end
  end

  defp sample_code(methods, options \\ [alias: true, free: true]) do
    alias_statement = if options[:alias], do: "alias Ecto.Multi"
    use_module = if options[:free], do: "Oban.Worker", else: "Oban.Pro.Worker"

    """
    defmodule AlasPoorYorickWorker do

      use #{use_module}
      #{alias_statement}

      @impl Worker
      #{methods}

    end
    """
  end
end
