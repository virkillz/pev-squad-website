defmodule PevSquad.Repo.Migrations.AddLocaleToUsers do
  use Ecto.Migration

  # The language emails are sent in ("id" or "en"). Nil until the member
  # registers, logs in or switches language; nil means the site default.
  def change do
    alter table(:users) do
      add :locale, :string
    end
  end
end
