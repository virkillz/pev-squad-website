defmodule PevSquadWeb.ReviewLive.Show do
  use PevSquadWeb, :live_view

  alias PevSquad.Accounts.Scope
  alias PevSquad.Reviews
  alias PevSquad.Reviews.Review

  import PevSquadWeb.ReviewComponents
  import PevSquadWeb.RiderComponents, only: [type_label: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:reviews}>
      <div :if={@review.status != :published} class="band band-tight band-white">
        <div class="notice">
          <%= if @review.status == :pending do %>
            <strong>Waiting for a moderator.</strong>
            Only you and the moderators can see this until it's approved.
          <% else %>
            <strong>Sent back by a moderator:</strong> {@review.rejection_reason}
            <.link navigate={~p"/reviews/#{@review.id}/edit"} class="link-orange">
              Edit and resubmit
            </.link>
          <% end %>
        </div>
      </div>

      <article class="detail-grid">
        <div class="detail-cell detail-rail">
          <div class="detail-rail-inner">
            <span class="meta-text">
              Review {String.pad_leading(to_string(@review.id), 2, "0")}{if @review.featured,
                do: " // Featured"}
            </span>
            <span class="detail-rail-title">{model_name(@review.pev_model)}</span>
            <span class="meta-text">{type_label(@review.pev_model.pev_type)}</span>
          </div>
        </div>

        <div class="detail-cell detail-main">
          <span class="detail-badge">Overall: {fmt(@review.overall)} / 10</span>
          <div>
            <span class="eyebrow">
              {if @review.featured, do: "★ Featured Rider Review", else: "Community Review"} · {model_name(
                @review.pev_model
              )}
            </span>
            <h1 class={[
              "detail-headline",
              String.length(@review.headline) > 18 && "detail-headline-long"
            ]}>
              {@review.headline}
            </h1>
          </div>
          <div class="detail-body">
            <div>
              <h3>[01] The Ride</h3>
              <p :for={para <- paragraphs(@review.the_ride)}>{para}</p>
            </div>
            <div :if={@review.the_catch}>
              <h3>[02] The Catch</h3>
              <p :for={para <- paragraphs(@review.the_catch)}>{para}</p>
            </div>
          </div>
          <div class="cross cross-a"></div>
        </div>

        <div class="detail-cell detail-side">
          <figure
            :if={@review.author_profile && @review.author_profile.avatar_path}
            class="detail-figure"
          >
            <img src={@review.author_profile.avatar_path} alt={author_name(@review)} />
            <figcaption class="detail-figure-label">
              <span class="detail-figure-title">The Reviewer</span>
              <span class="meta-text">{author_name(@review)}</span>
            </figcaption>
          </figure>
          <div class="detail-data">
            <div class="detail-data-head">
              <h2 class="detail-data-title">Rating Data</h2>
              <span :if={@review.km_on_unit} class="meta-text">
                {format_km(@review.km_on_unit)} km on unit
              </span>
            </div>
            <div class="stat-row">
              <span>Reviewer</span>
              <b>
                <.link
                  :if={@review.author_profile && @review.author_profile.is_public}
                  navigate={~p"/community/#{@review.author_profile.slug}"}
                >
                  {author_name(@review)}{if @review.featured, do: " ★"}
                </.link>
                <span :if={!(@review.author_profile && @review.author_profile.is_public)}>
                  {author_name(@review)}
                </span>
              </b>
            </div>
            <div class="stat-row">
              <span>Class</span><b>{type_label(@review.pev_model.pev_type)}</b>
            </div>
            <div class="stat-row"><span>Rating</span><b>{stars(@review.overall)}</b></div>
            <div style="margin: 1.25rem 0 1.5rem;">
              <.rating_row
                :for={{label, score} <- Review.scores(@review)}
                label={label}
                score={score}
              />
            </div>
            <.link
              :if={@review.pev_model.approved}
              navigate={~p"/models/#{@review.pev_model.slug}"}
              class="detail-cta"
            >
              All {model_name(@review.pev_model)} Reviews ≫
            </.link>
            <div :if={@can_edit?} class="flex gap-3" style="margin-top:1rem;">
              <.link navigate={~p"/reviews/#{@review.id}/edit"} class="btn btn-outline">Edit</.link>
            </div>
            <div class="cross cross-b"></div>
          </div>
        </div>
      </article>

      <section :if={@more != []} class="band band-black">
        <div class="section-head">
          <div>
            <span class="eyebrow">Keep reading</span>
            <h2 class="section-title">Next on the Sheet</h2>
          </div>
          <.link navigate={~p"/reviews"} class="btn btn-outline">Back to Reviews</.link>
        </div>
        <div class="index-list">
          <.link
            :for={{r, i} <- Enum.with_index(@more, 1)}
            class="index-row"
            navigate={~p"/reviews/#{r.id}"}
          >
            <div class="index-num">
              {String.pad_leading(to_string(i), 2, "0")} / {String.pad_leading(
                to_string(length(@more)),
                2,
                "0"
              )}
            </div>
            <div class="index-title">{model_name(r.pev_model)}</div>
            <div class="index-desc">{r.summary}</div>
            <div class="index-meta">
              {String.upcase(type_label(r.pev_model.pev_type))} · {fmt(r.overall)}
            </div>
          </.link>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    review = Reviews.get_review!(scope, id)

    more =
      Reviews.list_published_reviews(limit: 4)
      |> Enum.reject(&(&1.id == review.id))
      |> Enum.take(3)

    {:ok,
     socket
     |> assign(:page_title, "#{model_name(review.pev_model)} review")
     |> assign(:page_description, review.summary)
     |> assign(:review, review)
     |> assign(:can_edit?, Reviews.own?(scope, review))
     |> assign(:staff?, Scope.staff?(scope))
     |> assign(:more, more)}
  end

  defp paragraphs(text), do: String.split(text, ~r/\n\s*\n/, trim: true)

  defp format_km(km) do
    km
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
