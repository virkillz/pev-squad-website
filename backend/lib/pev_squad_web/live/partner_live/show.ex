defmodule PevSquadWeb.PartnerLive.Show do
  use PevSquadWeb, :live_view

  alias PevSquad.Partners
  alias PevSquad.Partners.Partner

  import PevSquadWeb.PartnerComponents
  import PevSquadWeb.EventComponents, only: [event_row: 1]
  import PevSquadWeb.RiderComponents, only: [rider_card: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:community}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">
            <.link navigate={back_path(@partner)} style="text-decoration:none;">
              02 / {plural_kind_label(@partner.kind)}
            </.link>
          </span>
          <span
            :if={@partner.vehicle_focus}
            class="badge"
            style="background:var(--black); color:var(--orange);"
          >
            {focus_label(@partner.vehicle_focus)}
          </span>
        </div>
        <h1 class="event-detail-title">{@partner.name}</h1>
        <p :if={@partner.tagline} class="page-intro">{@partner.tagline}</p>
      </section>

      <section class="band band-black">
        <div class="event-detail-grid">
          <div class="space-y-8">
            <div :if={@partner.description} class="prose-body">
              <p :for={para <- paragraphs(@partner.description)}>{para}</p>
            </div>

            <div :if={@partner.collaboration_note} class="space-y-3">
              <span class="eyebrow">{gettext("How we work together")}</span>
              <div class="prose-body">
                <p :for={para <- paragraphs(@partner.collaboration_note)}>{para}</p>
              </div>
            </div>

            <ul class="event-facts">
              <li :if={@partner.region}>
                <span class="k">{gettext("Rides in")}</span><span>{@partner.region}</span>
              </li>
              <li :if={@partner.collaboration_types != []}>
                <span class="k">{gettext("Partnership")}</span>
                <span>
                  {Enum.map_join(@partner.collaboration_types, " · ", &Partner.collaboration_label/1)}
                </span>
              </li>
              <li :if={@partner.partner_since}>
                <span class="k">{gettext("Since")}</span>
                <span>{PevSquadWeb.Locale.strftime(@partner.partner_since, "%B %Y")}</span>
              </li>
              <li :if={@events != []}>
                <span class="k">{gettext("Together")}</span><span>{together_label(length(@events))}</span>
              </li>
            </ul>
          </div>

          <aside class="space-y-4">
            <.partner_logo partner={@partner} class="is-large" />
            <div :if={@links != []} class="flex flex-wrap gap-2" id="partner-links">
              <a
                :for={{label, href} <- @links}
                href={href}
                target="_blank"
                rel="noopener"
                class="filter-tag"
              >
                {label} ↗
              </a>
            </div>
            <.link
              :if={@staff?}
              navigate={~p"/admin/partners/#{@partner.id}/edit"}
              class="btn btn-ghost w-full text-center"
            >
              {gettext("Edit partner")}
            </.link>
          </aside>
        </div>
      </section>

      <section :if={@riders != []} class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Also in The Squad")}</span>
            <h2 class="section-title">{gettext("Our Riders")}</h2>
          </div>
        </div>
        <div class="grid grid-3" id="partner-riders">
          <.rider_card :for={rider <- @riders} rider={rider} />
        </div>
      </section>

      <section
        :if={@events != []}
        class={["band", if(@riders == [], do: "band-white", else: "band-black")]}
      >
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Track record")}</span>
            <h2 class="section-title">{gettext("Events Together")}</h2>
          </div>
        </div>
        <div class="index-list" id="partner-events">
          <.event_row :for={event <- @events} event={event} past={past?(event, @now)} />
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    partner = Partners.get_public_partner!(slug)

    {:ok,
     socket
     |> assign(:page_title, partner.name)
     |> assign(
       :page_description,
       partner.tagline || gettext("%{kind} of PEV Squad.", kind: kind_label(partner.kind))
     )
     |> assign(:partner, partner)
     |> assign(:links, social_links(partner))
     |> assign(:events, Partners.list_partner_events(partner))
     |> assign(:riders, community_riders(partner, socket.assigns.current_scope))
     |> assign(:now, DateTime.utc_now())
     |> assign(:staff?, PevSquad.Accounts.Scope.staff?(socket.assigns.current_scope))}
  end

  defp community_riders(%Partner{kind: :community} = partner, scope) do
    PevSquad.Riders.list_community_riders(partner,
      exclude_users: PevSquad.Safety.hidden_user_ids(scope)
    )
  end

  defp community_riders(_brand, _scope), do: []

  defp past?(event, now), do: DateTime.compare(event.ends_at || event.starts_at, now) == :lt

  defp back_path(%Partner{kind: :community}), do: ~p"/community#partner-communities"
  defp back_path(%Partner{kind: :brand}), do: ~p"/community#brand-partners"

  defp plural_kind_label(:community), do: gettext("Partner Communities")
  defp plural_kind_label(:brand), do: gettext("Brand Partners")

  defp paragraphs(text), do: String.split(text, ~r/\n\s*\n/, trim: true)
end
