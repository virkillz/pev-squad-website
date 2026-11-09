defmodule PevSquad.Repo.Migrations.CreateListings do
  use Ecto.Migration

  def change do
    create table(:listings) do
      add :kind, :string, null: false, default: "member"
      add :seller_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :category, :string, null: false
      add :condition, :string, null: false
      add :price_idr, :bigint, null: false
      add :negotiable, :boolean, null: false, default: false
      add :quantity, :integer, null: false, default: 1
      add :city, :string, null: false
      add :km, :integer
      add :description, :text, null: false
      add :whatsapp, :string
      add :instagram, :string
      add :photos, :jsonb, null: false, default: "[]"

      add :status, :string, null: false, default: "pending"
      add :rejection_reason, :string
      add :moderated_by_id, references(:users, on_delete: :nilify_all)

      # Visibility is worked out from these, so nothing has to flip a
      # status when a listing goes stale (see PevSquad.Listings).
      add :approved_at, :utc_datetime
      add :last_checked_at, :utc_datetime
      add :reminded_at, :utc_datetime
      add :sold_at, :utc_datetime
      add :hidden_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:listings, [:seller_id])
    create index(:listings, [:status, :last_checked_at])
  end
end
