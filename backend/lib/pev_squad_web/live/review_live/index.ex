defmodule PevSquadWeb.ReviewLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Reviews

  import PevSquadWeb.ReviewComponents

  @filter_keys ~w(all euc escooter esk8 ebike)

  defp filters do
    [
      {gettext("All"), "all"},
      {"EUC", "euc"},
      {gettext("Scooter"), "escooter"},
      {"Esk8", "esk8"},
      {"E-Bike", "ebike"}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:reviews}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">04 / {gettext("Ridden, not sponsored")}</span>
          <span class="tag-scribble">{gettext("no bs")}</span>
        </div>
        <h1 class="page-title">{gettext("Reviews")}</h1>
        <p class="page-intro">
          {gettext(
            "Honest breakdowns of EUCs, performance scooters, and esk8 gear — rated by squad members who actually own and ride them."
          )}
        </p>
      </section>

      <section class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">{gettext("Everything, ranked")}</span>
            <h2 class="section-title">{gettext("The Sheet")}</h2>
            <p class="section-lede">
              {gettext(
                "Every model the squad has rated, ranked by the average of its riders' overall scores."
              )}
            </p>
          </div>
          <.link navigate={~p"/reviews/new"} class="btn btn-solid">{gettext("Write a Review")}</.link>
        </div>
        <.sheet_table :if={@sheet != []} rows={@sheet} />
        <p :if={@sheet == []} class="section-lede">{gettext("No ratings in this category yet.")}</p>
      </section>

      <section class="band band-white">
        <div class="filters" style="margin-bottom:2rem;">
          <.link
            :for={{label, key} <- @filters}
            patch={if key == "all", do: ~p"/reviews", else: ~p"/reviews?filter=#{key}"}
            class={["filter-tag", @filter == key && "active"]}
          >
            {label}
          </.link>
        </div>

        <div :if={@reviews != []} class="grid grid-3" id="review-cards">
          <.review_card :for={review <- @reviews} review={review} />
        </div>
        <p :if={@reviews == []} class="section-lede">
          {gettext("Nothing here yet. Own one?")}
          <.link navigate={~p"/reviews/new"} class="link-orange">{gettext("Review it.")}</.link>
        </p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Reviews"))
     |> assign(
       :page_description,
       gettext(
         "EUC, scooter and esk8 reviews from PEV Squad riders who own the gear — ranked, ridden, not sponsored."
       )
     )
     |> assign(:filters, filters())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filter =
      if params["filter"] in @filter_keys, do: params["filter"], else: "all"

    opts = filter_opts(filter)

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:sheet, Reviews.sheet(opts))
     |> assign(
       :reviews,
       Reviews.list_published_reviews(
         opts ++
           [
             limit: 30,
             exclude_users: PevSquad.Safety.hidden_user_ids(socket.assigns.current_scope)
           ]
       )
     )}
  end

  defp filter_opts("all"), do: []
  defp filter_opts(type), do: [type: String.to_existing_atom(type)]
end
