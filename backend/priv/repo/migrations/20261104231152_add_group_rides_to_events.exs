defmodule PevSquad.Repo.Migrations.AddGroupRidesToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      # "official" (PEV Squad organizes or collaborates — see `role`) or
      # "group_ride" (hosted by the member in created_by_id).
      add :category, :string, null: false, default: "official"
    end

    create index(:events, [:category, :status, :starts_at])
    create index(:events, [:created_by_id])
  end
end
