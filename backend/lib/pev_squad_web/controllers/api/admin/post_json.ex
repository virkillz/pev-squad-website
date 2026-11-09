defmodule PevSquadWeb.API.Admin.PostJSON do
  use PevSquadWeb, :verified_routes

  alias PevSquadWeb.API.Urls

  def index(%{posts: posts}), do: %{data: Enum.map(posts, &summary/1)}

  def show(%{post: post}), do: %{data: data(post)}

  defp summary(post) do
    post
    |> data()
    |> Map.update!(:translations, fn by_locale ->
      Map.new(by_locale, fn {locale, t} ->
        {locale, Map.take(t, [:title, :machine_translated])}
      end)
    end)
  end

  defp data(post) do
    %{
      id: post.id,
      kind: post.kind,
      slug: post.slug,
      status: post.status,
      published_at: post.published_at,
      topic: post.topic,
      cover_url: Urls.absolute(post.cover_path),
      source_name: post.source_name,
      source_url: post.source_url,
      event_id: post.event_id,
      translations:
        Map.new(post.translations, fn t ->
          {t.locale,
           %{
             title: t.title,
             excerpt: t.excerpt,
             body: t.body,
             machine_translated: t.machine_translated
           }}
        end),
      url: public_url(post),
      admin_url: url(~p"/admin/posts/#{post.id}/edit"),
      inserted_at: post.inserted_at,
      updated_at: post.updated_at
    }
  end

  defp public_url(%{kind: :news, slug: slug}), do: url(~p"/news/#{slug}")
  defp public_url(%{kind: :article, slug: slug}), do: url(~p"/articles/#{slug}")
end
