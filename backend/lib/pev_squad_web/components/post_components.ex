defmodule PevSquadWeb.PostComponents do
  @moduledoc "Labels, links and cards for news and articles."
  use PevSquadWeb, :html

  alias PevSquad.Posts
  alias PevSquad.Posts.Post
  alias PevSquadWeb.Locale

  def kind_label(:news), do: gettext("News")
  def kind_label(:article), do: gettext("Article")

  def topic_label(:community), do: gettext("Community")
  def topic_label(:industry), do: gettext("Industry")
  def topic_label(:regulation), do: gettext("Regulation")
  def topic_label(:safety), do: gettext("Safety")
  def topic_label(:maintenance), do: gettext("Maintenance")
  def topic_label(:guide), do: gettext("Guide")
  def topic_label(:gear), do: gettext("Gear")
  def topic_label(:story), do: gettext("Rider Story")

  def topic_options, do: Enum.map(Post.topics(), &{topic_label(&1), &1})

  @doc "The language's own name, so it reads right whatever the UI language is."
  def language_name("id"), do: "Bahasa Indonesia"
  def language_name("en"), do: "English"
  def language_name(other), do: other

  def post_path(%Post{kind: :article, slug: slug}), do: ~p"/articles/#{slug}"
  def post_path(%Post{slug: slug}), do: ~p"/news/#{slug}"

  @doc "\"09 Nov 2026\" in Jakarta time."
  def post_date(%Post{published_at: nil}), do: nil

  def post_date(%Post{published_at: at}) do
    at |> DateTime.shift_zone!("Asia/Jakarta") |> Locale.strftime("%d %b %Y")
  end

  @doc "Kind or topic · date · reading time, for cards and the post header."
  def post_meta(post, translation) do
    label = if post.topic, do: topic_label(post.topic), else: kind_label(post.kind)

    [
      label,
      post_date(post),
      post.kind == :article &&
        gettext("%{count} min read", count: Posts.reading_minutes(translation))
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  attr :post, Post, required: true
  attr :id, :string, default: nil

  def post_card(assigns) do
    assigns = assign(assigns, :t, Posts.translation_for(assigns.post, Locale.current()))

    ~H"""
    <.link navigate={post_path(@post)} class="card post-card" id={@id} lang={@t.locale}>
      <img
        :if={@post.cover_path}
        src={@post.cover_path}
        alt=""
        class="post-card-cover"
        loading="lazy"
      />
      <div :if={!@post.cover_path} class="post-card-cover is-blank" aria-hidden="true">
        <span>{kind_label(@post.kind)}</span>
      </div>
      <div class="card-body">
        <div class="card-meta" style="margin-top:0;">
          {post_meta(@post, @t)}
          <span
            :if={@t.locale != Locale.current()}
            class="post-card-lang"
            title={language_name(@t.locale)}
          >
            {String.upcase(@t.locale)}
          </span>
        </div>
        <h3 class="card-title" style="margin-top:0.6rem;">{@t.title}</h3>
        <p class="card-desc">{Posts.excerpt(@t)}</p>
      </div>
      <div :if={@post.source_name} class="card-foot">
        <span>{gettext("Source")}: {@post.source_name}</span>
      </div>
    </.link>
    """
  end
end
