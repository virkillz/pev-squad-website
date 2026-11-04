defmodule Mix.Tasks.PevSquad.ImportMembers do
  @shortdoc "Imports rider profiles from the member sign-up CSV"

  @moduledoc """
  Imports rider profiles from the Google Form export.

      mix pev_squad.import_members "../member pev squad.csv" \\
        --photos ../images/community --cards ../community.html

  * `--photos DIR` — photos named after each alias (`wynn.jpeg`)
  * `--cards FILE` — the prototype community.html, for polished bios

  Re-running is safe: aliases that already exist are skipped. Imported
  profiles are unclaimed; link them to members at /admin/riders.
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, paths, _} = OptionParser.parse(args, strict: [photos: :string, cards: :string])

    csv =
      case paths do
        [csv] -> csv
        _ -> Mix.raise("Usage: mix pev_squad.import_members CSV [--photos DIR] [--cards FILE]")
      end

    Mix.Task.run("app.start")

    results = PevSquad.Riders.MemberImport.run(csv, opts)

    for {status, alias_name, detail} <- results do
      Mix.shell().info("#{String.pad_trailing(to_string(status), 9)} #{alias_name} — #{detail}")
    end

    counts = Enum.frequencies_by(results, &elem(&1, 0))

    Mix.shell().info(
      "\n#{counts[:imported] || 0} imported, #{counts[:skipped] || 0} skipped, #{counts[:error] || 0} failed"
    )
  end
end
