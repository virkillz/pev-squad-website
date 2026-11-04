defmodule Mix.Tasks.PevSquad.SetRole do
  @shortdoc "Sets a user's role: member, moderator or admin"

  @moduledoc """
  Promote or demote a user.

      mix pev_squad.set_role rider@example.com moderator

  The user must have registered already.
  """
  use Mix.Task

  @roles ~w(member moderator admin)

  @impl Mix.Task
  def run([email, role]) when role in @roles do
    Mix.Task.run("app.start")

    case PevSquad.Accounts.get_user_by_email(email) do
      nil ->
        Mix.raise("No user with email #{email}. They need to register first.")

      user ->
        {:ok, user} = PevSquad.Accounts.set_user_role(user, String.to_existing_atom(role))
        Mix.shell().info("#{user.email} is now #{user.role}")
    end
  end

  def run(_args) do
    Mix.raise("Usage: mix pev_squad.set_role EMAIL member|moderator|admin")
  end
end
