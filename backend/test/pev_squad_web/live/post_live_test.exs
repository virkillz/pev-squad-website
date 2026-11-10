defmodule PevSquadWeb.PostLiveTest do
  use PevSquadWeb.ConnCase

  import Phoenix.LiveViewTest
  import PevSquad.AccountsFixtures
  import PevSquad.EventsFixtures
  import PevSquad.PostsFixtures

  alias PevSquad.Posts

  defp t(locale, title, body \\ "Body text."), do: %{locale: locale, title: title, body: body}
  defp in_indonesian(conn), do: init_test_session(conn, %{"locale" => "id"})

  describe "lists" do
    test "news and articles are listed separately", %{conn: conn} do
      post_fixture(translations: [t("en", "Bromo Ride Recap")])
      post_fixture(kind: :article, topic: :safety, translations: [t("en", "Gear Up Right")])
      post_fixture(status: :draft, translations: [t("en", "Secret Draft")])

      {:ok, lv, html} = live(conn, ~p"/news")
      assert has_element?(lv, "#posts", "Bromo Ride Recap")
      refute html =~ "Gear Up Right"
      refute html =~ "Secret Draft"

      {:ok, lv, _html} = live(conn, ~p"/articles")
      assert has_element?(lv, "#posts", "Gear Up Right")
      assert has_element?(lv, "#post-topics", "Safety")
    end

    test "filters articles by topic", %{conn: conn} do
      post_fixture(kind: :article, topic: :safety, translations: [t("en", "Gear Up Right")])
      post_fixture(kind: :article, topic: :maintenance, translations: [t("en", "Tyre Pressure")])

      {:ok, lv, _html} = live(conn, ~p"/articles?topic=maintenance")
      assert has_element?(lv, "#posts", "Tyre Pressure")
      refute has_element?(lv, "#posts", "Gear Up Right")
    end

    test "says so when there's nothing yet", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/news")
      assert has_element?(lv, "#no-posts")
    end

    test "cards show each post in the reader's language when it exists", %{conn: conn} do
      post_fixture(translations: [t("id", "Judul Indonesia"), t("en", "English Title")])
      post_fixture(translations: [t("id", "Hanya Indonesia")])

      {:ok, _lv, html} = live(conn, ~p"/news")
      assert html =~ "English Title"
      refute html =~ "Judul Indonesia"
      assert html =~ "Hanya Indonesia"
      assert html =~ ~s|title="Bahasa Indonesia"|
    end
  end

  describe "post page" do
    test "renders Markdown safely", %{conn: conn} do
      post =
        post_fixture(
          translations: [
            t("en", "Safety First", "## Gear\n\n- **Helmet**\n\n<script>alert(1)</script>")
          ]
        )

      {:ok, lv, html} = live(conn, ~p"/news/#{post.slug}")
      assert has_element?(lv, "#post-body h2", "Gear")
      assert has_element?(lv, "#post-body li strong", "Helmet")
      refute html =~ "<script>alert(1)"
    end

    test "falls back to the other language and says so", %{conn: conn} do
      post = post_fixture(translations: [t("id", "Laporan Bromo", "Isinya.")])

      {:ok, lv, html} = live(conn, ~p"/news/#{post.slug}")
      assert html =~ "Laporan Bromo"
      assert has_element?(lv, "#post-fallback", "Not available in English yet")
      assert has_element?(lv, ~s|article#post[lang="id"]|)
    end

    test "the fallback note is in the reader's language", %{conn: conn} do
      post = post_fixture(translations: [t("en", "Only English")])

      {:ok, lv, _html} = live(in_indonesian(conn), ~p"/news/#{post.slug}")
      assert has_element?(lv, "#post-fallback", "Belum tersedia dalam Bahasa Indonesia")
      assert has_element?(lv, ~s|article#post[lang="en"]|)
    end

    test "shows the reader's language and links the other one", %{conn: conn} do
      post = post_fixture(translations: [t("id", "Judul", "Isi."), t("en", "Title", "Text.")])

      {:ok, lv, html} = live(conn, ~p"/news/#{post.slug}")
      assert html =~ "Title"
      refute has_element?(lv, "#post-fallback")
      assert has_element?(lv, ~s|#post-languages a[href="/news/#{post.slug}?locale=id"]|)

      {:ok, _lv, html} = live(in_indonesian(conn), ~p"/news/#{post.slug}")
      assert html =~ "Judul"
    end

    test "tells search engines about both languages", %{conn: conn} do
      post = post_fixture(translations: [t("id", "Judul"), t("en", "Title")])

      html = conn |> get(~p"/news/#{post.slug}") |> html_response(200)
      assert html =~ ~s|rel="alternate" hreflang="id"|
      assert html =~ ~s|rel="alternate" hreflang="en"|
      assert html =~ ~s|property="og:type" content="article"|
    end

    test "labels machine translations", %{conn: conn} do
      post =
        post_fixture(
          translations: [t("id", "Judul"), Map.put(t("en", "Title"), :machine_translated, true)]
        )

      {:ok, lv, _html} = live(conn, ~p"/news/#{post.slug}")
      assert has_element?(lv, "#post-machine")
    end

    test "outside news links its source", %{conn: conn} do
      post =
        post_fixture(
          source_name: "Kompas",
          source_url: "https://kompas.com/pev",
          translations: [t("en", "New Rules")]
        )

      {:ok, lv, _html} = live(conn, ~p"/news/#{post.slug}")
      assert has_element?(lv, ~s|#post-source a[href="https://kompas.com/pev"]|, "Kompas")
    end

    test "a recap and its event link to each other", %{conn: conn} do
      event = event_fixture(title: "Ngeride ke Bromo")
      post = post_fixture(event_id: event.id, translations: [t("en", "Bromo Recap")])

      {:ok, lv, _html} = live(conn, ~p"/news/#{post.slug}")
      assert has_element?(lv, ~s|#post-event a[href="/events/#{event.slug}"]|)

      {:ok, lv, _html} = live(conn, ~p"/events/#{event.slug}")
      assert has_element?(lv, ~s|#event-recaps a[href="/news/#{post.slug}"]|, "Bromo Recap")
    end

    test "shows its own album, else its event's", %{conn: conn} do
      event = event_fixture()

      event_album =
        PevSquad.GalleryFixtures.album_fixture(%{
          "title" => "Event Photos",
          "event_id" => event.id
        })

      PevSquad.GalleryFixtures.photo_fixture(event_album)
      own = PevSquad.GalleryFixtures.album_fixture(%{"title" => "Own Photos"})
      PevSquad.GalleryFixtures.photo_fixture(own)

      recap = post_fixture(event_id: event.id, translations: [t("en", "Recap")])
      {:ok, lv, _html} = live(conn, ~p"/news/#{recap.slug}")

      assert has_element?(
               lv,
               ~s|#post-album a[href="/gallery/#{event_album.slug}"]|,
               "Event Photos"
             )

      linked =
        post_fixture(event_id: event.id, album_id: own.id, translations: [t("en", "Linked")])

      {:ok, lv, _html} = live(conn, ~p"/news/#{linked.slug}")
      assert has_element?(lv, "#post-album", "Own Photos")

      {:ok, lv, _html} = live(conn, ~p"/news/#{post_fixture().slug}")
      refute has_element?(lv, "#post-album")
    end

    test "the wrong section redirects to the right one", %{conn: conn} do
      post = post_fixture(kind: :article)

      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/news/#{post.slug}")
      assert to == ~p"/articles/#{post.slug}"
    end

    test "drafts 404 for readers but show to staff", %{conn: conn} do
      post = post_fixture(status: :draft)

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/news/#{post.slug}") end

      conn = log_in_user(conn, staff_scope_fixture().user)
      {:ok, lv, _html} = live(conn, ~p"/news/#{post.slug}")
      assert has_element?(lv, "#post-not-live")
      assert has_element?(lv, "#edit-post")
    end
  end

  test "the home page features the latest post", %{conn: conn} do
    post_fixture(translations: [t("en", "Fresh Off the Wire")])

    {:ok, lv, _html} = live(conn, ~p"/")
    assert has_element?(lv, "#latest-post", "Fresh Off the Wire")
  end

  test "the RSS feed lists published posts", %{conn: conn} do
    post = post_fixture(translations: [t("en", "Feed & Friends")])
    post_fixture(status: :draft, translations: [t("en", "Not Yet")])

    conn = get(conn, ~p"/feed.xml")
    body = response(conn, 200)
    assert response_content_type(conn, :xml) =~ "rss+xml"
    assert body =~ "Feed &amp; Friends"
    assert body =~ "/news/#{post.slug}"
    refute body =~ "Not Yet"
  end

  describe "admin" do
    setup %{conn: conn} do
      staff = staff_scope_fixture()
      %{conn: log_in_user(conn, staff.user), staff: staff}
    end

    test "picks a photo album", %{conn: conn} do
      album = PevSquad.GalleryFixtures.album_fixture(%{"title" => "Picked Album"})
      post = post_fixture(status: :draft)

      {:ok, lv, _html} = live(conn, ~p"/admin/posts/#{post.id}/edit")

      {:ok, _show, _html} =
        lv
        |> form("#post-form", post: %{album_id: album.id})
        |> render_submit()
        |> follow_redirect(conn)

      assert Posts.get_post!(staff_scope_fixture(), post.id).album_id == album.id
    end

    test "writes a post in both languages", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/posts/new?kind=article")
      assert has_element?(lv, "#tab-id")
      assert has_element?(lv, "#tab-en")

      {:ok, _show, html} =
        lv
        |> form("#post-form",
          post: %{
            kind: "article",
            topic: "maintenance",
            status: "published",
            translations: %{
              "0" => %{
                locale: "id",
                title: "Cara Cek Ban",
                body: "Cek tekanan **setiap** minggu."
              },
              "1" => %{
                locale: "en",
                title: "Checking Your Tyres",
                body: "Check the pressure **every** week.",
                machine_translated: "true"
              }
            }
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Checking Your Tyres"

      [post] = Posts.list_published_posts()
      assert post.slug == "cara-cek-ban"
      assert post.kind == :article
      assert Enum.find(post.translations, &(&1.locale == "en")).machine_translated
    end

    test "saves with only one language filled in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/posts/new")

      {:ok, _show, _html} =
        lv
        |> form("#post-form",
          post: %{
            status: "published",
            translations: %{
              "0" => %{locale: "id", title: "Kabar Singkat", body: "Isi."},
              "1" => %{locale: "en", title: "", body: ""}
            }
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      [post] = Posts.list_published_posts()
      assert Posts.locales(post) == ["id"]
    end

    test "asks for at least one language", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/posts/new")

      html =
        lv
        |> form("#post-form", post: %{translations: %{"0" => %{title: ""}, "1" => %{title: ""}}})
        |> render_submit()

      assert html =~ "write a title and text in at least one language"
    end

    test "previews the Markdown", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/posts/new")

      lv
      |> form("#post-form", post: %{translations: %{"0" => %{body: "## Hello"}}})
      |> render_change()

      lv |> element("button", "Preview") |> render_click()
      assert has_element?(lv, "#preview-id h2", "Hello")
    end

    test "adds an English translation to an existing post", %{conn: conn} do
      post = post_fixture(translations: [t("id", "Judul", "Isi.")])

      {:ok, lv, _html} = live(conn, ~p"/admin/posts/#{post.id}/edit")
      lv |> element("#tab-en") |> render_click()

      {:ok, _show, _html} =
        lv
        |> form("#post-form",
          post: %{translations: %{"1" => %{title: "Title", body: "Text."}}}
        )
        |> render_submit()
        |> follow_redirect(conn)

      post = Posts.get_post!(staff_scope_fixture(), post.id)
      assert Enum.sort(Posts.locales(post)) == ["en", "id"]
    end

    test "uploads a cover image", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/posts/new")

      cover =
        file_input(lv, "#post-form", :cover, [
          %{
            name: "cover.jpg",
            content: File.read!(PevSquad.RidersFixtures.image_fixture(1200, 800)),
            type: "image/jpeg"
          }
        ])

      render_upload(cover, "cover.jpg")

      {:ok, _show, _html} =
        lv
        |> form("#post-form",
          post: %{
            status: "published",
            translations: %{"0" => %{locale: "id", title: "Dengan Foto", body: "Isi."}}
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      [post] = Posts.list_published_posts()
      assert "/uploads/posts/" <> _ = post.cover_path
    end

    test "uploaded inline images give a line to paste", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/posts/new")

      images =
        file_input(lv, "#post-form", :images, [
          %{
            name: "inline.jpg",
            content: File.read!(PevSquad.RidersFixtures.image_fixture(400, 300)),
            type: "image/jpeg"
          }
        ])

      render_upload(images, "inline.jpg")
      assert render(lv) =~ "![](/uploads/posts/inline-"
    end

    test "lists and deletes posts", %{conn: conn} do
      post = post_fixture(translations: [t("en", "Delete Me")])

      {:ok, lv, _html} = live(conn, ~p"/admin/posts")
      assert has_element?(lv, "#posts", "Delete Me")

      lv |> element("#posts-#{post.id} a", "Delete") |> render_click()
      assert Posts.list_published_posts() == []
    end

    test "members can't open the admin form", %{conn: _conn} do
      conn = log_in_user(build_conn(), user_fixture())
      assert {:error, {:redirect, _}} = live(conn, ~p"/admin/posts/new")
    end
  end
end
