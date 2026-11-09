defmodule PevSquad.PostsFixtures do
  @moduledoc "Test helpers for news and articles."

  import PevSquad.EventsFixtures, only: [staff_scope_fixture: 0]

  @doc """
  A published news post with an Indonesian translation. Pass `translations:`
  to replace it, e.g. `[%{locale: "en", title: "…", body: "…"}]`.
  """
  def post_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, post} =
      PevSquad.Posts.create_post(
        staff_scope_fixture(),
        Enum.into(attrs, %{
          kind: :news,
          status: :published,
          published_at: DateTime.add(DateTime.utc_now(:second), -3600),
          translations: [%{locale: "id", title: "Kabar #{n}", body: "Isi kabar #{n}."}]
        })
      )

    post
  end
end
