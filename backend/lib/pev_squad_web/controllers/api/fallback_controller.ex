defmodule PevSquadWeb.API.FallbackController do
  @moduledoc """
  Turns `{:error, ...}` returned by API actions into the shared error shape.
  """
  use Phoenix.Controller, formats: [:json]

  alias PevSquadWeb.API.Errors

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    Errors.send_error(conn, :validation_failed, Errors.changeset_fields(changeset))
  end

  def call(conn, {:error, {:validation_failed, fields}}) when is_map(fields) do
    Errors.send_error(conn, :validation_failed, fields)
  end

  def call(conn, {:error, code})
      when code in [:not_found, :forbidden, :unauthorized, :conflict] do
    Errors.send_error(conn, code)
  end

  def call(conn, nil), do: Errors.send_error(conn, :not_found)
end
