defmodule PevSquad.Repo.Migrations.CreateRiderProfiles do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:rider_profiles) do
      # nil = imported from the sign-up form and not yet claimed by a member.
      add :user_id, references(:users, on_delete: :nilify_all)
      add :alias, :citext, null: false
      add :slug, :string, null: false
      # Private: never shown publicly.
      add :full_name, :string
      add :city, :string
      add :bio, :text
      add :primary_pev_type, :string, null: false, default: "euc"
      add :main_ride, :string
      add :instagram, :string
      add :avatar_path, :string
      # Consent to appear on the public site ("Bersedia dicantumkan di website?").
      add :is_public, :boolean, null: false, default: false
      add :featured_since, :utc_datetime
      add :source, :string, null: false, default: "member"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:rider_profiles, [:user_id])
    create unique_index(:rider_profiles, [:alias])
    create unique_index(:rider_profiles, [:slug])
    create index(:rider_profiles, [:is_public, :primary_pev_type])
  end
end
