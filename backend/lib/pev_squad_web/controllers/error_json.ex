defmodule PevSquadWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests
  (unknown /api routes, crashes). It uses the API's error shape, see
  `PevSquadWeb.API.Errors`.

  See config/config.exs.
  """
  alias PevSquadWeb.API.Errors

  def render("401.json", _assigns), do: Errors.body(:unauthorized)
  def render("403.json", _assigns), do: Errors.body(:forbidden)
  def render("404.json", _assigns), do: Errors.body(:not_found)

  def render(template, _assigns) do
    code = if String.starts_with?(template, "5"), do: "server_error", else: "bad_request"
    %{error: %{code: code, message: Phoenix.Controller.status_message_from_template(template)}}
  end
end
