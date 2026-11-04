defmodule PevSquadWeb.AuthTitles do
  @moduledoc """
  Page titles for the generated phx.gen.auth LiveViews, kept out of those
  files so they stay close to the generator output.
  """
  import Phoenix.Component, only: [assign: 3]

  @titles %{
    PevSquadWeb.UserLive.Login => "Log in",
    PevSquadWeb.UserLive.Registration => "Join the Squad",
    PevSquadWeb.UserLive.Confirmation => "Confirm",
    PevSquadWeb.UserLive.Settings => "Account"
  }

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign(socket, :page_title, Map.get(@titles, socket.view))}
  end
end
