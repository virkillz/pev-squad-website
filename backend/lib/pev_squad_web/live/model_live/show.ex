defmodule PevSquadWeb.ModelLive.Show do
  use PevSquadWeb, :live_view

  alias PevSquad.Reviews

  import PevSquadWeb.ReviewComponents
  import PevSquadWeb.RiderComponents, only: [type_label: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:reviews}>
      <section class="page-header">
        <div class="meta-row">
          <span class="eyebrow">
            <.link navigate={~p"/reviews"} style="text-decoration:none;">05 / Reviews</.link>
          </span>
          <span class="badge" style="background:var(--black); color:var(--orange);">
            {type_label(@model.pev_type)}
          </span>
        </div>
        <h1 class="event-detail-title">{model_name(@model)}</h1>
      </section>

      <section :if={@row} class="band band-tight band-black">
        <div class="statbar">
          <div class="stat">
            <div class="stat-n">{fmt(@row.overall)}</div>
            <div class="stat-l">Overall</div>
          </div>
          <div class="stat">
            <div class="stat-n">{fmt(@row.featured_avg)}</div>
            <div class="stat-l">★ Featured avg</div>
          </div>
          <div class="stat">
            <div class="stat-n">{fmt(@row.community_avg)}</div>
            <div class="stat-l">Community avg</div>
          </div>
          <div class="stat">
            <div class="stat-n">{@row.reviews}</div>
            <div class="stat-l">Reviews</div>
          </div>
        </div>
      </section>

      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">From riders who own one</span>
            <h2 class="section-title">The Reviews</h2>
          </div>
          <.link navigate={~p"/reviews/new?model=#{@model.slug}"} class="btn btn-primary">
            Review this model
          </.link>
        </div>
        <div :if={@reviews != []} class="grid grid-3">
          <.review_card :for={review <- @reviews} review={review} />
        </div>
        <p :if={@reviews == []} class="section-lede">No reviews yet — be the first.</p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    {model, row} = Reviews.get_model!(slug)

    {:ok,
     socket
     |> assign(:page_title, model_name(model))
     |> assign(
       :page_description,
       "#{model_name(model)} reviews from PEV Squad riders who own one."
     )
     |> assign(:model, model)
     |> assign(:row, row)
     |> assign(:reviews, Reviews.list_model_reviews(model))}
  end
end
