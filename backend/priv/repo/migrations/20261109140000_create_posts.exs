defmodule PevSquad.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    # News and articles. Language-neutral fields live here; the text lives in
    # post_translations, one row per language.
    create table(:posts) do
      # "news" | "article"
      add :kind, :string, null: false
      add :slug, :string, null: false
      # "draft" | "published". Published with a future published_at = scheduled.
      add :status, :string, null: false, default: "draft"
      add :published_at, :utc_datetime
      # community, industry, regulation, safety, maintenance, guide, gear, story
      add :topic, :string
      add :cover_path, :string
      # Outside news: where it came from.
      add :source_name, :string
      add :source_url, :string
      # A recap of this event.
      add :event_id, references(:events, on_delete: :nilify_all)
      add :author_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:posts, [:slug])
    create index(:posts, [:status, :kind, :published_at])
    create index(:posts, [:event_id])

    create table(:post_translations) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      # "id" | "en"
      add :locale, :string, null: false
      add :title, :string, null: false
      add :excerpt, :text
      # Markdown.
      add :body, :text, null: false
      # Filled by AI translation and not yet checked by a person.
      add :machine_translated, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:post_translations, [:post_id, :locale])
  end
end
