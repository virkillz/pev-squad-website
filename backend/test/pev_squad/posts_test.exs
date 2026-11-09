defmodule PevSquad.PostsTest do
  use PevSquad.DataCase

  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.PostsFixtures

  alias PevSquad.Posts
  alias PevSquad.Posts.Post

  defp t(locale, title, body \\ "Body"), do: %{locale: locale, title: title, body: body}

  describe "translations" do
    test "picks the reader's language, then Indonesian, then whatever there is" do
      both = post_fixture(translations: [t("id", "Judul"), t("en", "Title")])
      assert Posts.translation_for(both, "en").title == "Title"
      assert Posts.translation_for(both, "id").title == "Judul"

      id_only = post_fixture(translations: [t("id", "Judul")])
      assert Posts.translation_for(id_only, "en").title == "Judul"

      en_only = post_fixture(translations: [t("en", "Title")])
      assert Posts.translation_for(en_only, "id").title == "Title"
    end

    test "needs at least one language" do
      assert {:error, changeset} =
               Posts.create_post(staff_scope_fixture(), %{
                 kind: :news,
                 translations: [%{locale: "id", title: "", body: ""}]
               })

      assert "write a title and text in at least one language" in errors_on(changeset).translations
    end

    test "a blank language isn't saved, and blanking one deletes it" do
      staff = staff_scope_fixture()

      {:ok, post} =
        Posts.create_post(staff, %{
          kind: :article,
          translations: [t("id", "Judul"), %{locale: "en", title: "", excerpt: "", body: ""}]
        })

      assert Posts.locales(post) == ["id"]

      {:ok, post} =
        Posts.update_post(staff, post, %{
          translations: [
            %{id: hd(post.translations).id, locale: "id", title: "Judul"},
            t("en", "Title")
          ]
        })

      assert Enum.sort(Posts.locales(post)) == ["en", "id"]
      en = Enum.find(post.translations, &(&1.locale == "en"))
      id = Enum.find(post.translations, &(&1.locale == "id"))

      {:ok, post} =
        Posts.update_post(staff, post, %{
          translations: [
            %{id: id.id, locale: "id", title: "Judul"},
            %{id: en.id, locale: "en", title: "", excerpt: "", body: ""}
          ]
        })

      assert Posts.locales(post) == ["id"]
    end

    test "a half-filled language must have a title and text" do
      assert {:error, changeset} =
               Posts.create_post(staff_scope_fixture(), %{
                 kind: :news,
                 translations: [t("id", "Judul"), %{locale: "en", title: "Only a title"}]
               })

      assert %{translations: [%{}, %{body: ["can't be blank"]}]} = errors_on(changeset)
    end
  end

  describe "publishing" do
    test "drafts and scheduled posts stay off the public lists" do
      live = post_fixture()
      _draft = post_fixture(status: :draft)
      _scheduled = post_fixture(published_at: DateTime.add(DateTime.utc_now(:second), 3600))

      assert Enum.map(Posts.list_published_posts(), & &1.id) == [live.id]
    end

    test "publishing without a date uses now" do
      post = post_fixture(published_at: nil)
      assert post.published_at
      assert Posts.live?(post)
    end

    test "only staff can see a draft by its link" do
      draft = post_fixture(status: :draft)

      assert_raise Ecto.NoResultsError, fn -> Posts.get_public_post!(nil, draft.slug) end

      assert_raise Ecto.NoResultsError, fn ->
        Posts.get_public_post!(user_scope_fixture(), draft.slug)
      end

      assert Posts.get_public_post!(staff_scope_fixture(), draft.slug).id == draft.id
    end

    test "lists filter by kind and topic, newest first" do
      older = post_fixture(published_at: DateTime.add(DateTime.utc_now(:second), -7200))
      newer = post_fixture()
      guide = post_fixture(kind: :article, topic: :maintenance)

      assert Enum.map(Posts.list_published_posts(kind: :news), & &1.id) == [newer.id, older.id]
      assert Enum.map(Posts.list_published_posts(topic: :maintenance), & &1.id) == [guide.id]
      assert Posts.published_topics(:article) == [:maintenance]
    end

    test "recaps are listed on their event" do
      event = event_fixture()
      recap = post_fixture(event_id: event.id)
      _other = post_fixture()

      assert Enum.map(Posts.list_event_posts(event), & &1.id) == [recap.id]
    end
  end

  describe "slugs and sources" do
    test "the slug comes from the Indonesian title and doesn't change" do
      staff = staff_scope_fixture()
      post = post_fixture(translations: [t("en", "Ride Report"), t("id", "Laporan Ride Bromo")])
      assert post.slug == "laporan-ride-bromo"

      [id | _] = Enum.sort_by(post.translations, & &1.locale, :desc)
      {:ok, post} = Posts.update_post(staff, post, %{translations: [%{id: id.id, title: "Baru"}]})
      assert post.slug == "laporan-ride-bromo"
    end

    test "a generated slug that's taken gets a number" do
      a = post_fixture(translations: [t("id", "Ride Recap")])
      b = post_fixture(translations: [t("id", "Ride Recap")])
      assert {a.slug, b.slug} == {"ride-recap", "ride-recap-2"}

      assert {:error, changeset} =
               Posts.create_post(staff_scope_fixture(), %{
                 kind: :news,
                 slug: "ride-recap",
                 translations: [t("id", "Lain")]
               })

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "the source link must be a web link" do
      changeset =
        Post.changeset(%Post{translations: []}, %{
          kind: :news,
          source_url: "javascript:alert(1)",
          translations: [t("id", "Judul")]
        })

      assert "must be a link starting with https://" in errors_on(changeset).source_url
    end
  end

  describe "excerpts" do
    test "uses the summary, or the start of the text without Markdown" do
      assert Posts.excerpt(%Posts.Translation{excerpt: "Short.", body: "Long"}) == "Short."

      body = "## Heading\n\n![x](/a.webp)\n\nRide **fast** with [us](https://x.com)."
      assert Posts.excerpt(%Posts.Translation{body: body}) == "Ride fast with us."
    end
  end

  test "members can't manage posts" do
    assert_raise PevSquad.Posts.NotAuthorizedError, fn ->
      Posts.create_post(user_scope_fixture(), %{kind: :news})
    end
  end
end
