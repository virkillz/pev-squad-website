defmodule PevSquad.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "member"
    end

    create table(:events) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :kind, :string, null: false, default: "ride"
      add :role, :string, null: false, default: "organizer"
      add :partners, :string
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime
      add :timezone, :string, null: false, default: "Asia/Jakarta"
      add :location_name, :string
      add :meeting_point, :string
      add :description, :text
      add :capacity, :integer
      add :rsvp_deadline, :utc_datetime
      add :status, :string, null: false, default: "draft"
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:events, [:slug])
    create index(:events, [:status, :starts_at])
    create constraint(:events, :capacity_positive, check: "capacity IS NULL OR capacity > 0")

    create table(:event_rsvps) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:event_rsvps, [:event_id, :user_id])
    # Waitlist promotion picks the earliest waitlisted row per event.
    create index(:event_rsvps, [:event_id, :status, :inserted_at])
  end
end
