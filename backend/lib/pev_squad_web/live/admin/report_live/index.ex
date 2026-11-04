defmodule PevSquadWeb.Admin.ReportLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Events.Event
  alias PevSquad.Gallery.Photo
  alias PevSquad.Reviews.{PevModel, Review}
  alias PevSquad.Riders.RiderProfile
  alias PevSquad.Safety
  alias PevSquad.Safety.Report

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin · Safety</span>
            <h1 class="section-title">Reports</h1>
            <p class="section-lede">
              Grouped by item, oldest first. Reviews, photos and group rides with 3+ reports are hidden automatically until you decide.
            </p>
          </div>
        </div>

        <p :if={@groups == []} class="section-lede">All clear. No open reports.</p>

        <div class="space-y-6">
          <article :for={g <- @groups} id={"report-#{g.type}-#{g.id}"} class="notice space-y-3">
            <div class="flex flex-wrap gap-2 items-center">
              <span class="badge">{g.type}</span>
              <span
                :if={hidden?(g.target)}
                class="badge"
                style="background:var(--black); color:var(--orange);"
              >
                Auto-hidden
              </span>
              <span class="meta-text">
                {length(g.reports)} {if length(g.reports) == 1, do: "report", else: "reports"} · {Enum.map_join(
                  g.reasons,
                  ", ",
                  fn {r, n} -> "#{Report.reason_label(r)} ×#{n}" end
                )}
              </span>
            </div>

            <div class="flex gap-4 items-start">
              <img
                :if={match?(%Photo{}, g.target)}
                src={g.target.thumb_path}
                alt=""
                style="width:140px; aspect-ratio:1; object-fit:cover;"
              />
              <div class="space-y-1">
                <p><strong>{describe(g.target)}</strong></p>
                <p :if={match?(%Review{}, g.target)}>{g.target.summary}</p>
                <p :if={match?(%RiderProfile{}, g.target)}>{g.target.bio}</p>
                <p :if={match?(%Event{}, g.target)}>{g.target.description}</p>
                <.link :if={link = view_link(g.target)} navigate={link} class="link-orange">
                  Open
                </.link>
              </div>
            </div>

            <ul class="space-y-1">
              <li :for={r <- g.reports} :if={r.notes} class="meta-text">“{r.notes}”</li>
            </ul>

            <form
              phx-submit="remove"
              class="flex flex-wrap gap-2 items-end"
              id={"remove-#{g.type}-#{g.id}"}
            >
              <input type="hidden" name="target_type" value={g.type} />
              <input type="hidden" name="target_id" value={g.id} />
              <input
                :if={match?(%Review{}, g.target)}
                name="note"
                class="input flex-1"
                placeholder="Note to the author (emailed)"
              />
              <.button :if={g.target} variant="primary">{remove_label(g.target)}</.button>
              <.button type="button" phx-click="dismiss" phx-value-type={g.type} phx-value-id={g.id}>
                {if g.target, do: "Dismiss — no action", else: "Close (already gone)"}
              </.button>
            </form>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Admin · Reports") |> load()}
  end

  defp load(socket),
    do: assign(socket, :groups, Safety.list_open_reports(socket.assigns.current_scope))

  @impl true
  def handle_event("dismiss", %{"type" => type, "id" => id}, socket) do
    {:ok, type} = Safety.parse_type(type)
    {:ok, _} = Safety.dismiss(socket.assigns.current_scope, type, String.to_integer(id))
    {:noreply, socket |> put_flash(:info, "Reports dismissed.") |> load()}
  end

  def handle_event("remove", %{"target_type" => type, "target_id" => id} = params, socket) do
    {:ok, type} = Safety.parse_type(type)

    {:ok, _} =
      Safety.remove_content(
        socket.assigns.current_scope,
        type,
        String.to_integer(id),
        params["note"],
        &url(~p"/reviews/#{&1.id}/edit")
      )

    {:noreply, socket |> put_flash(:info, "Removed and reports closed.") |> load()}
  end

  defp hidden?(%{status: :pending}), do: true
  defp hidden?(%Event{status: :hidden}), do: true
  defp hidden?(_), do: false

  defp describe(nil), do: "Already deleted"
  defp describe(%Review{} = r), do: "#{PevModel.full_name(r.pev_model)} — “#{r.headline}”"
  defp describe(%Photo{} = p), do: "#{p.title || "Untitled photo"} · #{p.album.title}"
  defp describe(%RiderProfile{} = p), do: "Profile: #{p.alias}"
  defp describe(%Event{} = e), do: "Group ride: #{e.title} · #{e.location_name}"

  defp view_link(%Review{id: id}), do: ~p"/reviews/#{id}"
  defp view_link(%Photo{album: album}), do: ~p"/gallery/#{album.slug}"
  defp view_link(%RiderProfile{is_public: true, slug: slug}), do: ~p"/community/#{slug}"
  defp view_link(%Event{slug: slug}), do: ~p"/events/#{slug}"
  defp view_link(_), do: nil

  defp remove_label(%Review{}), do: "Send review back"
  defp remove_label(%Photo{}), do: "Delete photo"
  defp remove_label(%RiderProfile{}), do: "Hide profile"
  defp remove_label(%Event{}), do: "Take ride down"
end
