defmodule PevSquad.Repo.Migrations.AddApiFieldsToUsersTokens do
  use Ecto.Migration

  # Personal API tokens (context "api") are listed and revoked by name in
  # /admin/api-tokens, expire on their own date and record when they were
  # last used. Other contexts leave these columns empty.
  def change do
    alter table(:users_tokens) do
      add :name, :string
      add :last_used_at, :utc_datetime
      add :expires_at, :utc_datetime
    end
  end
end
