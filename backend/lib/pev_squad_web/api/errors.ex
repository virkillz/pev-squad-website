defmodule PevSquadWeb.API.Errors do
  @moduledoc """
  The one error shape every `/api/v1` response uses (DESIGN.md §7.1):

      {"error": {"code": "validation_failed", "message": "...", "fields": {...}}}

  `fields` only appears for `validation_failed`. Messages follow the request
  locale.
  """
  use Gettext, backend: PevSquadWeb.Gettext

  import Plug.Conn

  @statuses %{
    unauthorized: 401,
    forbidden: 403,
    not_found: 404,
    conflict: 409,
    validation_failed: 422,
    rate_limited: 429
  }

  @doc "Sends an error response with the status that belongs to `code`."
  def send_error(conn, code, fields \\ nil) when is_map_key(@statuses, code) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(Map.fetch!(@statuses, code), Jason.encode!(body(code, fields)))
  end

  @doc "The error body for `code`, e.g. for `Phoenix.Controller.json/2`."
  def body(code, fields \\ nil) do
    error = %{code: Atom.to_string(code), message: message(code)}
    %{error: if(fields, do: Map.put(error, :fields, fields), else: error)}
  end

  def status(code), do: Map.fetch!(@statuses, code)

  @doc "Changeset errors as `%{field => [message]}`, translated, nested for assocs."
  def changeset_fields(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, &PevSquadWeb.CoreComponents.translate_error/1)
  end

  def message(:unauthorized), do: gettext("A valid API token is required.")
  def message(:forbidden), do: gettext("You don't have permission to do that.")
  def message(:not_found), do: gettext("Not found.")

  def message(:conflict),
    do: gettext("Only drafts can be changed through the API. Edit published items in /admin.")

  def message(:validation_failed), do: gettext("Some fields need fixing.")
  def message(:rate_limited), do: gettext("Too many requests. Try again in a moment.")
end
