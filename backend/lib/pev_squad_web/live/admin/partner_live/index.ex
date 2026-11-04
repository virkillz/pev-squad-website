defmodule PevSquadWeb.Admin.PartnerLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Partners

  import PevSquadWeb.PartnerComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin</span>
            <h1 class="section-title">Partners</h1>
            <p class="section-lede">
              Partner communities and brand partners, shown on the community page. Link them to events from the event form.
            </p>
          </div>
          <div class="flex gap-3">
            <.link navigate={~p"/admin/partners/new?kind=community"} class="btn btn-outline">
              New Community
            </.link>
            <.link navigate={~p"/admin/partners/new?kind=brand"} class="btn btn-primary">
              New Brand
            </.link>
          </div>
        </div>
        <.table
          id="partners"
          rows={@partners}
          row_click={fn p -> JS.navigate(~p"/admin/partners/#{p}/edit") end}
        >
          <:col :let={p} label="Name">{p.name}</:col>
          <:col :let={p} label="Kind">{kind_label(p.kind)}</:col>
          <:col :let={p} label="Details">{partner_meta(p)}</:col>
          <:col :let={p} label="Logo">{if p.logo_path, do: "✓", else: "—"}</:col>
          <:col :let={p} label="Order">{p.position}</:col>
          <:col :let={p} label="Status">{if p.published, do: "Listed", else: "Hidden"}</:col>
        </.table>
        <p :if={@partners == []} class="section-lede">No partners yet.</p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin · Partners")
     |> assign(:partners, Partners.list_all_partners(socket.assigns.current_scope))}
  end
end
