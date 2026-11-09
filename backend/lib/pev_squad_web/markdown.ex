defmodule PevSquadWeb.Markdown do
  @moduledoc """
  Renders post bodies. Raw HTML in the source is dropped, and the output is
  sanitized (no scripts, event handlers or `javascript:` links), so staff
  can't break the page by pasting markup.
  """

  @options [
    extension: [strikethrough: true, table: true, autolink: true],
    render: [unsafe: false],
    sanitize: MDEx.Document.default_sanitize_options()
  ]

  def to_html(nil), do: Phoenix.HTML.raw("")

  def to_html(markdown) when is_binary(markdown) do
    markdown |> MDEx.to_html!(@options) |> Phoenix.HTML.raw()
  end
end
