defmodule PevSquadWeb.Admin.PostLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Posts

  import PevSquadWeb.PostComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin</span>
            <h1 class="section-title">News &amp; Articles</h1>
          </div>
          <div class="flex flex-wrap gap-3">
            <.link navigate={~p"/admin/posts/new?kind=news"} class="btn btn-primary">New News</.link>
            <.link navigate={~p"/admin/posts/new?kind=article"} class="btn btn-outline">
              New Article
            </.link>
          </div>
        </div>

        <.table
          id="posts"
          rows={@streams.posts}
          row_click={fn {_id, post} -> JS.navigate(~p"/admin/posts/#{post}/edit") end}
        >
          <:col :let={{_id, post}} label="Date">{post_date(post) || "—"}</:col>
          <:col :let={{_id, post}} label="Title">{title(post)}</:col>
          <:col :let={{_id, post}} label="Kind">{kind_label(post.kind)}</:col>
          <:col :let={{_id, post}} label="Languages">{languages(post)}</:col>
          <:col :let={{_id, post}} label="Status">{status_label(post)}</:col>
          <:action :let={{_id, post}}>
            <.link navigate={post_path(post)} class="link-orange">View</.link>
          </:action>
          <:action :let={{id, post}}>
            <.link
              phx-click={JS.push("delete", value: %{id: post.id}) |> hide("##{id}")}
              data-confirm="Delete this post in every language?"
              class="link-orange"
            >
              Delete
            </.link>
          </:action>
        </.table>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin · News & Articles")
     |> stream(:posts, Posts.list_posts_for_staff(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    post = Posts.get_post!(scope, id)
    {:ok, _} = Posts.delete_post(scope, post)

    {:noreply, stream_delete(socket, :posts, post)}
  end

  defp title(post), do: Posts.translation_for(post, "en").title

  # "ID · EN (AI)"
  defp languages(post) do
    post.translations
    |> Enum.sort_by(& &1.locale, :desc)
    |> Enum.map_join(" · ", fn t ->
      String.upcase(t.locale) <> if(t.machine_translated, do: " (AI)", else: "")
    end)
  end

  defp status_label(post) do
    cond do
      post.status == :draft -> "Draft"
      Posts.live?(post) -> "Published"
      true -> "Scheduled"
    end
  end
end
