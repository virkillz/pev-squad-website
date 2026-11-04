defmodule PevSquad.Repo.Migrations.CreatePartners do
  use Ecto.Migration

  def change do
    # Partner communities (REJS, SNOI…) and brand partners, managed by staff.
    create table(:partners) do
      # "community" | "brand"
      add :kind, :string, null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :tagline, :string
      add :description, :text
      add :logo_path, :string
      # Communities: where they ride ("Surabaya & Malang").
      add :region, :string
      # Communities: "euc" | "escooter" | "esk8" | "ebike" | "mixed".
      add :vehicle_focus, :string
      # Brands: sponsor, dealer, gear, venue, food_drink, media, event_partner.
      add :collaboration_types, {:array, :string}, null: false, default: []
      # "How we work together", shown on the partner page.
      add :collaboration_note, :text
      add :partner_since, :date
      add :website, :string
      add :instagram, :string
      add :tiktok, :string
      add :youtube, :string
      add :published, :boolean, null: false, default: true
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:partners, [:slug])
    create index(:partners, [:kind, :published, :position])

    create table(:event_partners, primary_key: false) do
      add :event_id, references(:events, on_delete: :delete_all), null: false, primary_key: true

      add :partner_id, references(:partners, on_delete: :delete_all),
        null: false,
        primary_key: true
    end

    create index(:event_partners, [:partner_id])
  end
end
