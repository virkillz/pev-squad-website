defmodule PevSquad.Repo.Migrations.CreateReportsAndBlocks do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :reporter_id, references(:users, on_delete: :nilify_all)
      # "review" | "photo" | "profile" — polymorphic, no FK.
      add :target_type, :string, null: false
      add :target_id, :bigint, null: false
      # The member whose content it is (so their content can be blocked/traced).
      add :target_user_id, references(:users, on_delete: :nilify_all)
      add :reason, :string, null: false
      add :notes, :text
      add :status, :string, null: false, default: "open"
      add :resolution, :string
      add :resolved_by_id, references(:users, on_delete: :nilify_all)
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:reports, [:status, :target_type, :target_id])

    # One open report per member per item.
    create unique_index(:reports, [:reporter_id, :target_type, :target_id],
             where: "status = 'open'",
             name: :reports_one_open_per_reporter_index
           )

    create table(:blocks) do
      add :blocker_id, references(:users, on_delete: :delete_all), null: false
      add :blocked_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:blocks, [:blocker_id, :blocked_id])
    create constraint(:blocks, :no_self_block, check: "blocker_id <> blocked_id")
  end
end
