defmodule PevSquad.Repo.Migrations.AddStatusToRiderProfiles do
  use Ecto.Migration

  def change do
    alter table(:rider_profiles) do
      # "active" | "inactive" | "banned". Set by staff only.
      add :status, :string, null: false, default: "active"
      # Public statement shown on a banned rider's page, and when.
      add :ban_reason, :text
      add :banned_at, :utc_datetime
      # Staff override: hides the profile whatever the member's own
      # is_public choice says.
      add :hidden_by_staff, :boolean, null: false, default: false
    end
  end
end
