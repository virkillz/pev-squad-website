defmodule PevSquad.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:pev_models) do
      add :pev_type, :string, null: false
      add :brand, :string, null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      # Members can add a missing model while writing a review; it stays
      # pending (not listed publicly) until a moderator approves it.
      add :approved, :boolean, null: false, default: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pev_models, [:slug])

    create unique_index(:pev_models, ["lower(brand)", "lower(name)"],
             name: :pev_models_brand_name_index
           )

    create table(:reviews) do
      add :pev_model_id, references(:pev_models, on_delete: :restrict), null: false
      add :author_id, references(:users, on_delete: :delete_all), null: false
      add :headline, :string, null: false
      add :summary, :string, null: false
      add :the_ride, :text, null: false
      add :the_catch, :text
      add :km_on_unit, :integer

      # Scores in tenths: 94 = 9.4 / 10. App/FW is optional.
      add :score_power, :integer, null: false
      add :score_range, :integer, null: false
      add :score_comfort, :integer, null: false
      add :score_build, :integer, null: false
      add :score_value, :integer, null: false
      add :score_app, :integer
      add :overall, :integer, null: false

      add :status, :string, null: false, default: "pending"
      add :rejection_reason, :string
      # Snapshot at publish time: the author held the Featured badge.
      add :featured, :boolean, null: false, default: false
      add :published_at, :utc_datetime
      add :moderated_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:reviews, [:pev_model_id, :author_id])
    create index(:reviews, [:status, :published_at])
    create index(:reviews, [:author_id])

    for score <-
          ~w(score_power score_range score_comfort score_build score_value score_app overall) do
      create constraint(:reviews, :"#{score}_range",
               check: "#{score} IS NULL OR #{score} BETWEEN 0 AND 100"
             )
    end
  end
end
