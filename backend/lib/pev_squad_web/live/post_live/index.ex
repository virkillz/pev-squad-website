defmodule PevSquadWeb.PostLive.Index do
  @moduledoc "The news and articles lists (`/news`, `/articles`)."
  use PevSquadWeb, :live_view

  alias PevSquad.Posts
  alias PevSquad.Posts.Post

  import PevSquadWeb.PostComponents

  @per_page 12

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:news}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">07 / {gettext("Read up")}</span>
          <span class="tag-scribble">{gettext("off the wire")}</span>
        </div>
        <h1 class="page-title">{@heading}</h1>
        <p class="page-intro">{@intro}</p>
      </section>

      <section class="band band-white">
        <div class="section-head">
          <div class="filters" style="margin-bottom:0;" id="post-kinds">
            <.link navigate={~p"/news"} class={["filter-tag", @kind == :news && "active"]}>
              {gettext("News")}
            </.link>
            <.link navigate={~p"/articles"} class={["filter-tag", @kind == :article && "active"]}>
              {gettext("Articles")}
            </.link>
          </div>
          <.link :if={@staff?} navigate={~p"/admin/posts/new?kind=#{@kind}"} class="btn btn-outline">
            {if @kind == :article, do: gettext("New Article"), else: gettext("New Post")}
          </.link>
        </div>

        <div :if={@topics != []} class="filters" style="margin-bottom:2rem;" id="post-topics">
          <.link patch={base_path(@kind)} class={["filter-tag", is_nil(@topic) && "active"]}>
            {gettext("All")}
          </.link>
          <.link
            :for={topic <- @topics}
            patch={base_path(@kind) <> "?topic=#{topic}"}
            class={["filter-tag", @topic == topic && "active"]}
          >
            {topic_label(topic)}
          </.link>
        </div>

        <div :if={@posts != []} class="grid grid-3" id="posts">
          <.post_card :for={post <- @posts} post={post} id={"post-#{post.id}"} />
        </div>
        <p :if={@posts == []} class="section-lede" id="no-posts">
          {if @kind == :article,
            do: gettext("No articles yet — the first guides are on the way."),
            else: gettext("No news yet. Check back soon.")}
        </p>

        <nav :if={@page > 1 or @more?} class="pager" aria-label={gettext("Pages")}>
          <span class="pager-count">{gettext("Page %{page}", page: @page)}</span>
          <div class="pager-links">
            <.link
              :if={@page > 1}
              patch={page_path(@kind, @topic, @page - 1)}
              class="filter-tag"
              rel="prev"
            >
              ← {gettext("Newer")}
            </.link>
            <.link
              :if={@more?}
              patch={page_path(@kind, @topic, @page + 1)}
              class="filter-tag"
              rel="next"
            >
              {gettext("Older")} →
            </.link>
          </div>
        </nav>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    kind = if socket.assigns.live_action == :articles, do: :article, else: :news

    {heading, intro} =
      case kind do
        :article ->
          {gettext("Articles"),
           gettext(
             "Guides, safety, maintenance and rider stories — the things worth knowing before and after you ride."
           )}

        :news ->
          {gettext("News"),
           gettext(
             "What's happening in the squad and the wider PEV world — ride recaps, announcements, new gear and the rules of the road."
           )}
      end

    {:ok,
     socket
     |> assign(:kind, kind)
     |> assign(:heading, heading)
     |> assign(:intro, intro)
     |> assign(:page_title, heading)
     |> assign(:page_description, intro)
     |> assign(:topics, Posts.published_topics(kind))
     |> assign(:staff?, PevSquad.Accounts.Scope.staff?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    kind = socket.assigns.kind
    topic = parse_topic(params["topic"])
    page = parse_page(params["page"])

    # One extra row tells us whether there's an older page.
    posts =
      Posts.list_published_posts(
        kind: kind,
        topic: topic,
        limit: @per_page + 1,
        offset: (page - 1) * @per_page
      )

    {:noreply,
     socket
     |> assign(:topic, topic)
     |> assign(:page, page)
     |> assign(:posts, Enum.take(posts, @per_page))
     |> assign(:more?, length(posts) > @per_page)}
  end

  defp parse_topic(value) do
    Enum.find(Post.topics(), &(Atom.to_string(&1) == value))
  end

  defp parse_page(value) do
    case Integer.parse(value || "") do
      {n, ""} when n > 1 -> n
      _ -> 1
    end
  end

  defp base_path(:article), do: ~p"/articles"
  defp base_path(:news), do: ~p"/news"

  defp page_path(kind, topic, page) do
    query = [topic: topic, page: page != 1 && page] |> Enum.filter(fn {_, v} -> v end)
    if query == [], do: base_path(kind), else: base_path(kind) <> "?" <> URI.encode_query(query)
  end
end
