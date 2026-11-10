defmodule PevSquadWeb.Admin.PostLive.Form do
  use PevSquadWeb, :live_view

  alias PevSquad.Posts
  alias PevSquad.Posts.{Images, Post}

  import PevSquadWeb.PostComponents

  @tz "Asia/Jakarta"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {@page_title}
            <:subtitle>
              <.link navigate={~p"/admin/posts"} class="link-orange">All posts</.link>
              · Times are Jakarta time (WIB).
            </:subtitle>
          </.header>

          <.form for={@form} id="post-form" phx-change="validate" phx-submit="save" class="space-y-2">
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input
                field={@form[:kind]}
                type="select"
                label="Kind"
                options={[{"News", :news}, {"Article", :article}]}
              />
              <.input
                field={@form[:topic]}
                type="select"
                label="Topic"
                prompt="—"
                options={topic_options()}
              />
              <.input
                field={@form[:status]}
                type="select"
                label="Status"
                options={[{"Draft", :draft}, {"Published", :published}]}
              />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:published_at]}
                type="datetime-local"
                label="Publish date (blank = when published; future = scheduled)"
                value={local_value(@form[:published_at])}
              />
              <.input
                field={@form[:slug]}
                type="text"
                label="URL slug (leave blank to generate)"
                placeholder="ngeride-ke-bromo-recap"
              />
            </div>

            <%!-- One tab per language. Both stay in the form so both are saved. --%>
            <div class="space-y-2" id="post-translations">
              <div class="filters" style="margin-bottom:0.5rem;" role="tablist">
                <button
                  :for={tf <- @translation_forms}
                  type="button"
                  role="tab"
                  phx-click="tab"
                  phx-value-locale={tf[:locale].value}
                  class={["filter-tag", @tab == tf[:locale].value && "active"]}
                  id={"tab-#{tf[:locale].value}"}
                  aria-selected={to_string(@tab == tf[:locale].value)}
                >
                  {language_name(tf[:locale].value)} · {tab_state(tf)}
                </button>
              </div>
              <p class="panel-sub" style="margin-top:0;">
                Write in one language or both. A blank language isn't saved; readers then get the other one.
              </p>
              <p
                :for={msg <- Enum.map(@form[:translations].errors, &translate_error/1)}
                :if={@form.source.action in [:insert, :update]}
                class="text-error"
                id="translations-error"
              >
                {msg}
              </p>

              <.inputs_for :let={tf} field={@form[:translations]}>
                <div hidden={@tab != tf[:locale].value} id={"translation-#{tf[:locale].value}"}>
                  <input type="hidden" name={tf[:locale].name} value={tf[:locale].value} />
                  <.input field={tf[:title]} type="text" label="Title" />
                  <.input
                    field={tf[:excerpt]}
                    type="textarea"
                    label="Summary (cards and link previews; blank = start of the text)"
                    rows="2"
                  />
                  <div class="flex justify-between items-end gap-3">
                    <span class="label">
                      Text (Markdown: ## heading, **bold**, - list, [link](https://…))
                    </span>
                    <button type="button" phx-click="toggle_preview" class="btn btn-ghost btn-sm">
                      {if @preview?, do: "Edit", else: "Preview"}
                    </button>
                  </div>
                  <div hidden={@preview?}>
                    <.input field={tf[:body]} type="textarea" rows="18" />
                  </div>
                  <div
                    :if={@preview? and @tab == tf[:locale].value}
                    class="post-body post-preview"
                    id={"preview-#{tf[:locale].value}"}
                  >
                    {PevSquadWeb.Markdown.to_html(tf[:body].value)}
                  </div>
                  <.input
                    field={tf[:machine_translated]}
                    type="checkbox"
                    label="Machine translated — not checked by a person yet"
                  />
                </div>
              </.inputs_for>
            </div>

            <div class="space-y-2" id="inline-images">
              <span class="label">Images for the text</span>
              <.live_file_input upload={@uploads.images} class="input" />
              <p class="panel-sub" style="margin-top:0;">
                Uploaded images get a line to paste into the text where they should appear.
              </p>
              <p :for={err <- upload_errors(@uploads.images)} class="text-error">
                {upload_error(err)}
              </p>
              <p :if={@image_error} class="text-error">{@image_error}</p>
              <ul class="space-y-1">
                <li :for={url <- @inline_images} class="flex gap-3 items-center">
                  <img src={url} alt="" style="width:64px; height:48px; object-fit:cover;" />
                  <code class="inline-snippet">![]({url})</code>
                </li>
              </ul>
            </div>

            <div class="space-y-2">
              <span class="label">Cover image</span>
              <div class="flex gap-4 items-start">
                <img
                  :if={@post.cover_path && @uploads.cover.entries == []}
                  src={@post.cover_path}
                  alt=""
                  style="width:200px; aspect-ratio:3/2; object-fit:cover;"
                />
                <.live_img_preview
                  :for={entry <- @uploads.cover.entries}
                  entry={entry}
                  style="width:200px; aspect-ratio:3/2; object-fit:cover; border:var(--bw) solid var(--orange);"
                />
                <div class="flex-1 space-y-2">
                  <.live_file_input upload={@uploads.cover} class="input" />
                  <p class="panel-sub" style="margin-top:0;">
                    Landscape works best. Up to 15 MB; it's resized and location data removed.
                  </p>
                  <p :for={err <- upload_errors(@uploads.cover)} class="text-error">
                    {upload_error(err)}
                  </p>
                  <%= for entry <- @uploads.cover.entries, err <- upload_errors(@uploads.cover, entry) do %>
                    <p class="text-error">{upload_error(err)}</p>
                  <% end %>
                  <button
                    :if={@post.cover_path && @uploads.cover.entries == []}
                    type="button"
                    phx-click="remove_cover"
                    class="btn btn-ghost"
                  >
                    Remove cover
                  </button>
                </div>
              </div>
              <p :if={@cover_error} class="text-error">{@cover_error}</p>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:source_name]}
                type="text"
                label="Source (outside news)"
                placeholder="Kompas, InMotion…"
              />
              <.input
                field={@form[:source_url]}
                type="url"
                label="Source link"
                placeholder="https://"
              />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:event_id]}
                type="select"
                label="Recap of event"
                prompt="—"
                options={@event_options}
              />
              <.input
                field={@form[:album_id]}
                type="select"
                label="Photo album (blank = the event's album, if any)"
                prompt="—"
                options={@album_options}
              />
            </div>

            <div class="flex flex-wrap gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">Save</.button>
              <.button navigate={~p"/admin/posts"}>Cancel</.button>
              <.button
                :if={@live_action == :edit}
                type="button"
                phx-click="delete"
                data-confirm="Delete this post in every language?"
                class="btn btn-ghost"
              >
                Delete
              </.button>
            </div>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:cover_error, nil)
     |> assign(:image_error, nil)
     |> assign(:inline_images, [])
     |> assign(:tab, "id")
     |> assign(:preview?, false)
     |> assign(:event_options, event_options(scope))
     |> assign(:album_options, album_options(scope))
     |> allow_upload(:cover,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: Images.max_bytes()
     )
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 5,
       max_file_size: Images.max_bytes(),
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    kind = if params["kind"] == "article", do: :article, else: :news

    socket
    |> assign(:page_title, if(kind == :article, do: "New Article", else: "New News Post"))
    |> assign(:post, %Post{kind: kind, translations: []})
    |> assign_form(Posts.change_post(Posts.new_post(kind)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    post = Posts.get_post!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit #{Posts.translation_for(post, "en").title}")
    |> assign(:post, post)
    |> assign_form(Posts.change_post(Posts.with_all_locales(post)))
  end

  defp assign_form(socket, changeset) do
    form = to_form(changeset)

    socket
    |> assign(:form, form)
    |> assign(
      :translation_forms,
      Phoenix.HTML.FormData.to_form(changeset, form, :translations, [])
    )
  end

  @impl true
  def handle_event("validate", %{"post" => params}, socket) do
    changeset = Posts.change_post(socket.assigns.post, to_utc(params))
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"post" => params}, socket) do
    scope = socket.assigns.current_scope
    params = to_utc(params)
    post = socket.assigns.post

    save = fn cover ->
      case socket.assigns.live_action do
        :new -> Posts.create_post(scope, params, cover)
        :edit -> Posts.update_post(scope, post, params, cover)
      end
    end

    # The temp file is deleted when the callback returns, so save inside it.
    result =
      case consume_uploaded_entries(socket, :cover, fn %{path: path}, _ -> {:ok, save.(path)} end) do
        [result] -> result
        [] -> save.(nil)
      end

    case result do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post saved.")
         |> push_navigate(to: post_path(post))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign_form(changeset) |> show_tab_with_errors(changeset)}

      {:error, :bad_image} ->
        {:noreply, assign(socket, :cover_error, "Couldn't read that image — try a JPG or PNG.")}
    end
  end

  def handle_event("tab", %{"locale" => locale}, socket) do
    {:noreply, assign(socket, :tab, locale)}
  end

  def handle_event("toggle_preview", _params, socket) do
    {:noreply, update(socket, :preview?, &(!&1))}
  end

  def handle_event("remove_cover", _params, socket) do
    {:ok, post} = Posts.remove_cover(socket.assigns.current_scope, socket.assigns.post)
    {:noreply, assign(socket, :post, %{socket.assigns.post | cover_path: post.cover_path})}
  end

  def handle_event("delete", _params, socket) do
    {:ok, _} = Posts.delete_post(socket.assigns.current_scope, socket.assigns.post)
    {:noreply, socket |> put_flash(:info, "Post deleted.") |> push_navigate(to: ~p"/admin/posts")}
  end

  defp handle_progress(:images, entry, socket) do
    if entry.done? do
      scope = socket.assigns.current_scope

      [result] =
        consume_uploaded_entries(socket, :images, fn %{path: path}, _ ->
          {:ok, Posts.store_inline_image(scope, path)}
        end)

      case result do
        {:ok, url} ->
          {:noreply,
           socket |> assign(:image_error, nil) |> update(:inline_images, &(&1 ++ [url]))}

        {:error, :bad_image} ->
          {:noreply, assign(socket, :image_error, "Couldn't read that image — try a JPG or PNG.")}
      end
    else
      {:noreply, socket}
    end
  end

  # After a failed save, open the language that has the problem.
  defp show_tab_with_errors(socket, changeset) do
    case Enum.find(changeset.changes[:translations] || [], &(not &1.valid?)) do
      nil -> socket
      bad -> assign(socket, :tab, Ecto.Changeset.get_field(bad, :locale))
    end
  end

  defp tab_state(tf) do
    cond do
      blank?(tf[:title].value) and blank?(tf[:body].value) -> "empty"
      tf[:machine_translated].value in [true, "true"] -> "AI"
      true -> "written"
    end
  end

  defp blank?(value), do: value in [nil, ""] or (is_binary(value) and String.trim(value) == "")

  defp event_options(scope) do
    scope
    |> PevSquad.Events.list_events_for_staff()
    |> Enum.filter(&(&1.category == :official))
    |> Enum.map(fn e -> {"#{Calendar.strftime(e.starts_at, "%Y-%m-%d")} · #{e.title}", e.id} end)
  end

  defp album_options(scope) do
    scope
    |> PevSquad.Gallery.list_albums_for_staff()
    |> Enum.map(&{if(&1.published, do: &1.title, else: "#{&1.title} (draft)"), &1.id})
  end

  # datetime-local values are Jakarta time; the schema stores UTC.
  defp to_utc(%{"published_at" => value} = params) when is_binary(value) and value != "" do
    value = if byte_size(value) == 16, do: value <> ":00", else: value

    with {:ok, naive} <- NaiveDateTime.from_iso8601(value),
         {:ok, dt} <- DateTime.from_naive(naive, @tz) do
      Map.put(
        params,
        "published_at",
        dt |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_iso8601()
      )
    else
      _ -> params
    end
  end

  defp to_utc(params), do: params

  defp local_value(%Phoenix.HTML.FormField{value: value}) do
    dt =
      case value do
        %DateTime{} = dt -> dt
        value when is_binary(value) -> with {:ok, dt, _} <- DateTime.from_iso8601(value), do: dt
        _ -> nil
      end

    case dt do
      %DateTime{} ->
        dt
        |> DateTime.shift_zone!(@tz)
        |> DateTime.to_naive()
        |> NaiveDateTime.to_iso8601()
        |> String.slice(0, 16)

      _ ->
        value
    end
  end

  defp upload_error(:too_large), do: "That image is over 15 MB."
  defp upload_error(:not_accepted), do: "Use a JPG, PNG or WebP."
  defp upload_error(:too_many_files), do: "Too many images at once."
  defp upload_error(_), do: "Upload failed — try again."
end
