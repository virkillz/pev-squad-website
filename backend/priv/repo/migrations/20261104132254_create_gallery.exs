defmodule PevSquad.Repo.Migrations.CreateGallery do
  use Ecto.Migration

  def change do
    create table(:albums) do
      add :title, :string, null: false
      add :slug, :string, null: false
      # Small line above the title: "Level P10, after hours".
      add :subtitle, :string
      add :description, :text
      add :taken_on, :date
      add :event_id, references(:events, on_delete: :nilify_all)
      add :published, :boolean, null: false, default: false
      add :open_for_uploads, :boolean, null: false, default: true
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:albums, [:slug])
    create index(:albums, [:published, :taken_on])

    create table(:photos) do
      add :album_id, references(:albums, on_delete: :delete_all), null: false
      add :uploader_id, references(:users, on_delete: :nilify_all)
      add :large_path, :string, null: false
      add :thumb_path, :string, null: false
      add :width, :integer
      add :height, :integer
      add :title, :string
      add :caption, :text
      # Short line under the title on the tile: "Level P10 // Night Session".
      add :meta, :string
      add :alt, :string
      # Grid footprint: "normal" (1x1), "big" (2x2) or "wide" (2x1).
      add :tile, :string, null: false, default: "normal"
      add :position, :integer, null: false, default: 0
      add :status, :string, null: false, default: "pending"
      add :moderated_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:photos, [:album_id, :status, :position])
    create index(:photos, [:status])
    create index(:photos, [:uploader_id])
  end
end
