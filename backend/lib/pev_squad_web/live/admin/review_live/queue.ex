defmodule PevSquadWeb.Admin.ReviewLive.Queue do
  use PevSquadWeb, :live_view

  alias PevSquad.Reviews
  alias PevSquad.Reviews.Review

  import PevSquadWeb.ReviewComponents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:reviews}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin · Moderation</span>
            <h1 class="section-title">Review Queue</h1>
            <p class="section-lede">{length(@reviews)} waiting, oldest first.</p>
          </div>
          <.link navigate={~p"/admin/models"} class="btn btn-outline">Model catalog</.link>
        </div>

        <p :if={@reviews == []} class="section-lede">All clear. Nothing waiting.</p>

        <div class="space-y-8">
          <article :for={review <- @reviews} id={"review-#{review.id}"} class="notice space-y-3">
            <div class="flex flex-wrap gap-2 items-center">
              <span class="badge">{model_name(review.pev_model)}</span>
              <span
                :if={!review.pev_model.approved}
                class="badge"
                style="background:var(--black); color:var(--orange);"
              >
                New model — approving the review adds it to the catalog
              </span>
              <span class="meta-text">by {author_name(review)} · overall {fmt(review.overall)}</span>
            </div>
            <h2 class="card-title">{review.headline}</h2>
            <p><strong>Summary:</strong> {review.summary}</p>
            <p><strong>The Ride:</strong> {review.the_ride}</p>
            <p :if={review.the_catch}><strong>The Catch:</strong> {review.the_catch}</p>
            <p class="meta-text">
              {Enum.map_join(Review.scores(review), " · ", fn {l, s} -> "#{l} #{fmt(s)}" end)}
              <span :if={review.km_on_unit}> ·   {review.km_on_unit} km</span>
            </p>
            <div class="flex flex-wrap gap-3 items-end">
              <.button phx-click="approve" phx-value-id={review.id} variant="primary">
                Approve
              </.button>
              <form phx-submit="reject" class="flex gap-2 items-end flex-1" id={"reject-#{review.id}"}>
                <input type="hidden" name="review_id" value={review.id} />
                <input
                  name="reason"
                  class="input"
                  placeholder="Why it's being sent back (emailed to the rider)"
                  required
                />
                <.button>Send back</.button>
              </form>
            </div>
          </article>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Admin · Review queue") |> load()}
  end

  defp load(socket),
    do: assign(socket, :reviews, Reviews.list_pending_reviews(socket.assigns.current_scope))

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    review = find(socket, id)
    {:ok, _} = Reviews.approve_review(socket.assigns.current_scope, review, &review_url/1)

    {:noreply,
     socket |> put_flash(:info, "Published #{model_name(review.pev_model)} review.") |> load()}
  end

  def handle_event("reject", %{"review_id" => id, "reason" => reason}, socket) do
    review = find(socket, id)

    case Reviews.reject_review(socket.assigns.current_scope, review, reason, &edit_url/1) do
      {:ok, _} ->
        {:noreply, socket |> put_flash(:info, "Sent back to the rider.") |> load()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Add a reason so the rider knows what to fix.")}
    end
  end

  defp find(socket, id), do: Enum.find(socket.assigns.reviews, &(to_string(&1.id) == id))

  defp review_url(review), do: url(~p"/reviews/#{review.id}")
  defp edit_url(review), do: url(~p"/reviews/#{review.id}/edit")
end
