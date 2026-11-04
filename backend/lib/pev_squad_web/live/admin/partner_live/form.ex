defmodule PevSquadWeb.Admin.PartnerLive.Form do
  use PevSquadWeb, :live_view

  alias PevSquad.Partners
  alias PevSquad.Partners.{Logo, Partner}

  import PevSquadWeb.PartnerComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {@page_title}
            <:subtitle>
              <.link navigate={~p"/admin/partners"} class="link-orange">All partners</.link>
            </:subtitle>
          </.header>

          <.form
            for={@form}
            id="partner-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
          >
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input
                field={@form[:kind]}
                type="select"
                label="Kind"
                options={[{"Partner Community", :community}, {"Brand Partner", :brand}]}
              />
              <div class="sm:col-span-2">
                <.input field={@form[:name]} type="text" label="Name" required />
              </div>
            </div>
            <.input
              field={@form[:slug]}
              type="text"
              label="URL slug (leave blank to generate)"
              placeholder="eboard-indonesia"
            />
            <.input
              field={@form[:tagline]}
              type="text"
              label="Tagline (one line on the card)"
              placeholder="EUC riders of Jakarta Selatan"
            />

            <div class="space-y-2">
              <span class="label">Logo</span>
              <div class="flex gap-4 items-start">
                <.partner_logo
                  :if={@uploads.logo.entries == []}
                  partner={@partner}
                  class="is-large"
                />
                <.live_img_preview
                  :for={entry <- @uploads.logo.entries}
                  entry={entry}
                  style="width:140px; aspect-ratio:1; object-fit:contain; background:#fff; border:var(--bw) solid var(--orange);"
                />
                <div class="flex-1 space-y-2">
                  <.live_file_input upload={@uploads.logo} class="input" />
                  <p class="panel-sub" style="margin-top:0;">
                    PNG with a transparent background works best. Up to 5 MB; it's fitted, never cropped.
                  </p>
                  <p :for={err <- upload_errors(@uploads.logo)} class="text-error">
                    {upload_error(err)}
                  </p>
                  <%= for entry <- @uploads.logo.entries, err <- upload_errors(@uploads.logo, entry) do %>
                    <p class="text-error">{upload_error(err)}</p>
                  <% end %>
                  <button
                    :if={@partner.logo_path && @uploads.logo.entries == []}
                    type="button"
                    phx-click="remove_logo"
                    class="btn btn-ghost"
                  >
                    Remove logo
                  </button>
                </div>
              </div>
              <p :if={@logo_error} class="text-error">{@logo_error}</p>
            </div>

            <div :if={@kind == :community} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input
                field={@form[:region]}
                type="text"
                label="Rides in"
                placeholder="Surabaya & Malang"
              />
              <.input
                field={@form[:vehicle_focus]}
                type="select"
                label="Vehicles"
                prompt="—"
                options={focus_options()}
              />
            </div>

            <fieldset :if={@kind == :brand} class="fieldset space-y-2">
              <span class="label">Partnership</span>
              <input type="hidden" name="partner[collaboration_types][]" value="" />
              <div class="flex flex-wrap gap-x-6 gap-y-2">
                <label
                  :for={{value, label} <- Partner.collaboration_types()}
                  class="flex gap-2 items-center cursor-pointer"
                >
                  <input
                    type="checkbox"
                    name="partner[collaboration_types][]"
                    value={value}
                    checked={value in collaboration_values(@form)}
                    class="checkbox"
                  />
                  <span>{label}</span>
                </label>
              </div>
            </fieldset>

            <.input field={@form[:description]} type="textarea" label="About" />
            <.input
              field={@form[:collaboration_note]}
              type="textarea"
              label="How we work together"
              placeholder="Co-hosts the Bromo getaway every year; lends their support car."
            />

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <.input field={@form[:website]} type="url" label="Website" placeholder="https://" />
              <.input
                field={@form[:youtube]}
                type="url"
                label="YouTube channel"
                placeholder="https://youtube.com/@…"
              />
              <.input field={@form[:instagram]} type="text" label="Instagram" placeholder="@handle" />
              <.input field={@form[:tiktok]} type="text" label="TikTok" placeholder="@handle" />
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <.input field={@form[:partner_since]} type="date" label="Partner since" />
              <.input
                field={@form[:position]}
                type="number"
                label="Order (lower shows first)"
              />
              <.input field={@form[:published]} type="checkbox" label="Listed on the site" />
            </div>

            <div class="flex flex-wrap gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">Save Partner</.button>
              <.button navigate={~p"/admin/partners"}>Cancel</.button>
              <.button
                :if={@live_action == :edit}
                type="button"
                phx-click="delete"
                data-confirm="Delete this partner? Event links to it are removed too."
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
    {:ok,
     socket
     |> assign(:logo_error, nil)
     |> allow_upload(:logo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: Logo.max_bytes()
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    kind = if params["kind"] == "brand", do: :brand, else: :community
    partner = %Partner{kind: kind}

    socket
    |> assign(:page_title, "New #{kind_label(kind)}")
    |> assign_partner(partner)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    partner = Partners.get_partner!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit #{partner.name}")
    |> assign_partner(partner)
  end

  defp assign_partner(socket, partner) do
    socket
    |> assign(:partner, partner)
    |> assign(:kind, partner.kind)
    |> assign(:form, to_form(Partners.change_partner(partner)))
  end

  @impl true
  def handle_event("validate", %{"partner" => params}, socket) do
    params = clean(params)
    changeset = Partners.change_partner(socket.assigns.partner, params)

    {:noreply,
     socket
     |> assign(:kind, Ecto.Changeset.get_field(changeset, :kind))
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"partner" => params}, socket) do
    scope = socket.assigns.current_scope
    params = clean(params)
    partner = socket.assigns.partner

    save = fn logo_source ->
      case socket.assigns.live_action do
        :new -> Partners.create_partner(scope, params, logo_source)
        :edit -> Partners.update_partner(scope, partner, params, logo_source)
      end
    end

    # The temp file is deleted when the callback returns, so save inside it.
    result =
      case consume_uploaded_entries(socket, :logo, fn %{path: path}, _ -> {:ok, save.(path)} end) do
        [result] -> result
        [] -> save.(nil)
      end

    case result do
      {:ok, partner} ->
        {:noreply,
         socket
         |> put_flash(:info, "Partner saved.")
         |> push_navigate(to: ~p"/partners/#{partner.slug}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, :bad_image} ->
        {:noreply, assign(socket, :logo_error, "Couldn't read that image — try a PNG or JPG.")}
    end
  end

  def handle_event("remove_logo", _params, socket) do
    {:ok, partner} = Partners.remove_logo(socket.assigns.current_scope, socket.assigns.partner)
    {:noreply, assign(socket, :partner, partner)}
  end

  def handle_event("delete", _params, socket) do
    {:ok, _} = Partners.delete_partner(socket.assigns.current_scope, socket.assigns.partner)

    {:noreply,
     socket |> put_flash(:info, "Partner deleted.") |> push_navigate(to: ~p"/admin/partners")}
  end

  # The hidden "" lets staff untick every box; it isn't a real value.
  defp clean(params) do
    Map.update(params, "collaboration_types", [], &Enum.reject(&1, fn v -> v == "" end))
  end

  defp collaboration_values(form) do
    form[:collaboration_types].value
    |> List.wrap()
    |> Enum.map(fn
      v when is_atom(v) -> v
      v -> String.to_existing_atom(v)
    end)
  end

  defp upload_error(:too_large), do: "That logo is over 5 MB."
  defp upload_error(:not_accepted), do: "Use a PNG, JPG or WebP."
  defp upload_error(:too_many_files), do: "One logo at a time."
  defp upload_error(_), do: "Upload failed — try again."
end
