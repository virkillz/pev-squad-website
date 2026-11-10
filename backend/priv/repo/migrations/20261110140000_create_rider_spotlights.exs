defmodule PevSquad.Repo.Migrations.CreateRiderSpotlights do
  use Ecto.Migration

  def change do
    # Rider of the day: one row per day (Jakarta date), picked automatically
    # on the first visit of the day, or by staff (picked_by_id).
    create table(:rider_spotlights) do
      add :date, :date, null: false
      add :rider_profile_id, references(:rider_profiles, on_delete: :delete_all), null: false
      add :picked_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:rider_spotlights, [:date])
    create index(:rider_spotlights, [:rider_profile_id, :date])
  end
end
