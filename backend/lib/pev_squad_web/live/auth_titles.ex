defmodule PevSquadWeb.AuthTitles do
  @moduledoc """
  Page titles for the generated phx.gen.auth LiveViews, kept out of those
  files so they stay close to the generator output.
  """
  use Gettext, backend: PevSquadWeb.Gettext
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :page_title, title(socket.view))}
  end

  defp title(PevSquadWeb.UserLive.Login), do: gettext("Log in")
  defp title(PevSquadWeb.UserLive.Registration), do: gettext("Join the Squad")
  defp title(PevSquadWeb.UserLive.Confirmation), do: gettext("Confirm")
  defp title(PevSquadWeb.UserLive.Settings), do: gettext("Account")
  defp title(_), do: nil
end
