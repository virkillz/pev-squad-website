defmodule PevSquadWeb.FeedController do
  @moduledoc "RSS 2.0 feed of the latest news and articles (`/feed.xml`)."
  use PevSquadWeb, :controller

  alias PevSquad.Posts
  alias PevSquadWeb.PostComponents

  def index(conn, _params) do
    locale = PevSquadWeb.Locale.current()
    posts = Posts.list_published_posts(limit: 30)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, render_feed(posts, locale))
  end

  defp render_feed(posts, locale) do
    base = String.trim_trailing(url(~p"/"), "/")

    items =
      Enum.map(posts, fn post ->
        t = Posts.translation_for(post, locale)
        link = base <> PostComponents.post_path(post)

        """
        <item>
          <title>#{escape(t.title)}</title>
          <link>#{escape(link)}</link>
          <guid isPermaLink="true">#{escape(link)}</guid>
          <pubDate>#{Calendar.strftime(post.published_at, "%a, %d %b %Y %H:%M:%S +0000")}</pubDate>
          <category>#{escape(PostComponents.kind_label(post.kind))}</category>
          <description>#{escape(Posts.excerpt(t))}</description>
        </item>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
    <channel>
      <title>PEV Squad</title>
      <link>#{base}/news</link>
      <atom:link href="#{base}/feed.xml" rel="self" type="application/rss+xml" />
      <description>#{escape(gettext("News and articles from PEV Squad, Indonesia's personal electric vehicle community."))}</description>
      <language>#{locale}</language>
    #{Enum.join(items)}</channel>
    </rss>
    """
  end

  defp escape(text) do
    text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end
end
