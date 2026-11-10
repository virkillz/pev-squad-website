defmodule PevSquad.Repo.Migrations.AddEventCoversAndPostAlbums do
  use Ecto.Migration

  def change do
    # One image per event, like a post's cover (/uploads/events/…).
    alter table(:events) do
      add :cover_path, :string
    end

    # A post's photo album. Events link to albums through albums.event_id.
    alter table(:posts) do
      add :album_id, references(:albums, on_delete: :nilify_all)
    end

    create index(:posts, [:album_id])
    create index(:albums, [:event_id])
  end
end
