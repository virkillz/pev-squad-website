defmodule Mix.Tasks.PevSquad.ImportGallery do
  @shortdoc "Imports the static prototype's gallery albums and photos"

  @moduledoc """
  Imports albums and photos from the prototype's gallery.html, credited to
  an admin account.

      mix pev_squad.import_gallery ../gallery.html admin@pev-squad.org

  Albums whose title already exists are skipped, so it's safe to re-run.
  """
  use Mix.Task

  @impl Mix.Task
  def run([html, email]) do
    Mix.Task.run("app.start")

    admin =
      PevSquad.Accounts.get_user_by_email(email) ||
        Mix.raise("No user with email #{email}.")

    for {title, status, count} <- PevSquad.Gallery.PrototypeImport.run(html, admin) do
      Mix.shell().info("#{String.pad_trailing(to_string(status), 9)} #{title} — #{count} photos")
    end
  end

  def run(_args), do: Mix.raise("Usage: mix pev_squad.import_gallery GALLERY_HTML ADMIN_EMAIL")
end
