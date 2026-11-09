defmodule PevSquad.Repo.Migrations.CreateRiderAffiliations do
  use Ecto.Migration

  def change do
    # Partner communities a rider also belongs to. Set by staff only.
    create table(:rider_affiliations, primary_key: false) do
      add :rider_profile_id, references(:rider_profiles, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :partner_id, references(:partners, on_delete: :delete_all),
        null: false,
        primary_key: true

      # Display order on the rider's card, 0 first.
      add :position, :integer, null: false, default: 0
    end

    create index(:rider_affiliations, [:partner_id])
  end
end
