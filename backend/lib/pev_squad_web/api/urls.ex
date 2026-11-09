defmodule PevSquadWeb.API.Urls do
  @moduledoc "Absolute URLs for API responses (the app can't resolve site-relative paths)."

  def absolute(nil), do: nil
  def absolute("http" <> _ = url), do: url
  def absolute("/" <> _ = path), do: PevSquadWeb.Endpoint.url() <> path

  @doc "Rewrites site-relative links and images in Markdown (`](/uploads/…)`) to absolute URLs."
  def absolutize_markdown(nil), do: nil

  def absolutize_markdown(markdown) when is_binary(markdown) do
    String.replace(
      markdown,
      ~r{\]\((/(?!/)[^)\s]*)},
      "](" <> PevSquadWeb.Endpoint.url() <> "\\1"
    )
  end

  @doc "Public site URL for a path."
  def site(path), do: PevSquadWeb.Endpoint.url() <> path
end
