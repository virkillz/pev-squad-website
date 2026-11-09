defmodule PevSquadWeb.API.Urls do
  @moduledoc "Absolute URLs for API responses (the app can't resolve site-relative paths)."

  def absolute(nil), do: nil
  def absolute("http" <> _ = url), do: url
  def absolute("/" <> _ = path), do: PevSquadWeb.Endpoint.url() <> path
end
