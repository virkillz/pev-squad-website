defmodule PevSquadWeb.PostLive.Show do
  @moduledoc """
  One news item or article (`/news/:slug`, `/articles/:slug`), in the
  reader's language when it has been written, otherwise the fallback
  (see `PevSquad.Posts.translation_for/2`).
  """
  use PevSquadWeb, :live_view

  alias PevSquad.Posts
  alias PevSquadWeb.Locale

  import PevSquadWeb.PostComponents
  import PevSquadWeb.GalleryComponents, only: [album_card: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:news}>
      <article lang={@t.locale} id="post">
        <section class="page-header">
          <div class="meta-row">
            <span class="eyebrow">
              <.link navigate={list_path(@post)} style="text-decoration:none;">
                07 / {if @post.kind == :article, do: gettext("Articles"), else: gettext("News")}
              </.link>
            </span>
            <span
              :if={@post.topic}
              class="badge"
              style="background:var(--black); color:var(--orange);"
            >
              {topic_label(@post.topic)}
            </span>
          </div>
          <h1 class="post-title">{@t.title}</h1>
          <p class="post-meta" id="post-meta">{post_meta(@post, @t)}</p>
        </section>

        <img :if={@post.cover_path} src={@post.cover_path} alt="" class="post-cover" />

        <section class="band band-white">
          <div class="post-layout">
            <div class="space-y-6">
              <div :if={!@live?} class="notice" id="post-not-live">
                {if @post.status == :draft,
                  do: gettext("Draft — only staff can see this page until it's published."),
                  else:
                    gettext("Scheduled for %{date} — only staff can see it until then.",
                      date: post_date(@post)
                    )}
              </div>
              <p :if={@t.locale != @locale} class="post-lang-note" id="post-fallback" lang={@locale}>
                {gettext("Not available in %{current} yet — showing the %{language} version.",
                  current: language_name(@locale),
                  language: language_name(@t.locale)
                )}
              </p>
              <p :if={@t.machine_translated} class="post-lang-note" id="post-machine" lang={@locale}>
                {gettext("Translated automatically and not checked by a person yet.")}
              </p>

              <p :if={@t.excerpt} class="post-lede">{@t.excerpt}</p>
              <div class="post-body" id="post-body">{PevSquadWeb.Markdown.to_html(@t.body)}</div>
            </div>

            <aside class="post-aside" lang={@locale}>
              <div :if={@post.source_url} class="post-aside-block" id="post-source">
                <span class="eyebrow">{gettext("Source")}</span>
                <a href={@post.source_url} target="_blank" rel="noopener nofollow" class="link-orange">
                  {@post.source_name || URI.parse(@post.source_url).host} ↗
                </a>
              </div>
              <div :if={@post.event} class="post-aside-block" id="post-event">
                <span class="eyebrow">{gettext("Event")}</span>
                <.link navigate={~p"/events/#{@post.event.slug}"} class="link-orange">
                  {@post.event.title} →
                </.link>
              </div>
              <div :if={@album} class="post-aside-block" id="post-album">
                <.album_card album={@album} />
              </div>
              <div :if={@other_locales != []} class="post-aside-block" id="post-languages">
                <span class="eyebrow">{gettext("Also in")}</span>
                <a
                  :for={locale <- @other_locales}
                  href={post_path(@post) <> "?locale=#{locale}"}
                  hreflang={locale}
                  lang={locale}
                  class="link-orange"
                >
                  {language_name(locale)}
                </a>
              </div>
              <div class="post-aside-block">
                <span class="eyebrow">{gettext("Share")}</span>
                <a
                  href={"https://wa.me/?text=" <> URI.encode_www_form(@t.title <> " " <> @url)}
                  target="_blank"
                  rel="noopener"
                  class="btn btn-solid"
                  id="share-whatsapp"
                >
                  WhatsApp
                </a>
              </div>
              <.link
                :if={@staff?}
                navigate={~p"/admin/posts/#{@post.id}/edit"}
                class="btn btn-ghost"
                id="edit-post"
              >
                {gettext("Edit post")}
              </.link>
            </aside>
          </div>
        </section>
      </article>

      <section :if={@more != []} class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Keep reading")}</span>
            <h2 class="section-title">
              {if @post.kind == :article, do: gettext("More Articles"), else: gettext("More News")}
            </h2>
          </div>
          <.link navigate={list_path(@post)} class="btn btn-outline">{gettext("See all")}</.link>
        </div>
        <div class="grid grid-3" id="more-posts">
          <.post_card :for={post <- @more} post={post} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    scope = socket.assigns.current_scope
    post = Posts.get_public_post!(scope, slug)

    if wrong_section?(post, socket.assigns.live_action) do
      {:ok, redirect(socket, to: post_path(post))}
    else
      {:ok, assign_post(socket, post)}
    end
  end

  defp wrong_section?(%{kind: :article}, action), do: action != :article
  defp wrong_section?(%{kind: :news}, action), do: action != :news

  defp assign_post(socket, post) do
    locale = Locale.current()
    t = Posts.translation_for(post, locale)
    url = url(~p"/") |> String.trim_trailing("/") |> Kernel.<>(post_path(post))
    others = Posts.locales(post) -- [t.locale]

    more =
      [kind: post.kind, limit: 4]
      |> Posts.list_published_posts()
      |> Enum.reject(&(&1.id == post.id))
      |> Enum.take(3)

    socket
    |> assign(:post, post)
    |> assign(:t, t)
    |> assign(:locale, locale)
    |> assign(:url, url)
    |> assign(:live?, Posts.live?(post))
    |> assign(:other_locales, others)
    |> assign(:staff?, PevSquad.Accounts.Scope.staff?(socket.assigns.current_scope))
    |> assign(:more, more)
    |> assign(
      :album,
      PevSquad.Gallery.album_for_post(post,
        exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
      )
    )
    |> assign(:page_title, t.title)
    |> assign(:page_description, Posts.excerpt(t))
    |> assign(:og_type, "article")
    |> assign(:og_image, post.cover_path && absolute(post.cover_path))
    |> assign(:alternate_locales, alternates(post, url))
  end

  # Only worth telling search engines when there really are two versions.
  defp alternates(post, url) do
    case Posts.locales(post) do
      [_, _ | _] = locales -> Enum.map(locales, &{&1, url <> "?locale=" <> &1})
      _ -> []
    end
  end

  defp absolute(path), do: String.trim_trailing(url(~p"/"), "/") <> path

  defp list_path(%{kind: :article}), do: ~p"/articles"
  defp list_path(_), do: ~p"/news"
end
