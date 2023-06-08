# WarnMultiErrorHandlingInObanJobs

## PRE-ALPHA

This is a credo check that tries to flag potential false negatives in certain types of error handling.
Specifically, an Oban job that returns an unmapped error 4 tuple from `Repo.transaction`. This will be
interpreted as a success, even though it prompts a warning in `iex`

```elixir
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
```

## TODOs

- [ ] proper testing, not just local ad hoc projects
- [ ] avoid false positives when error handling has happened (maybe, confidence mixed)
- [ ] avoid false negatives when `Multi.new ... Repo.transaction` are in a method called by `#perform`

## Installation

### this is not published in Hex yet, see the TODOs

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `warn_multi_error_handling_in_oban_jobs` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:warn_multi_error_handling_in_oban_jobs, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/warn_multi_error_handling_in_oban_jobs>.

