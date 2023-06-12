defmodule WarnMultiErrorHandlingInObanJobs.MixProject do
  use Mix.Project

  def project do
    [
      app: :warn_multi_error_handling_in_oban_jobs,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6.0", only: [:dev, :test], runtime: false}
    ]
  end
end
