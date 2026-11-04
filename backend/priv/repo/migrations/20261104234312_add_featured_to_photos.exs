defmodule PevSquad.Repo.Migrations.AddFeaturedToPhotos do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      # Shown in the home page carousel. featured_at orders it, newest first.
      add :featured, :boolean, null: false, default: false
      add :featured_at, :utc_datetime
    end

    create index(:photos, [:featured_at], where: "featured")
  end
end
