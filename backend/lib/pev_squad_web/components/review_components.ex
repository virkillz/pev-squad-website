defmodule PevSquadWeb.ReviewComponents do
  @moduledoc "Review cards, rating bars and the ranked Sheet, as in the prototype."
  use PevSquadWeb, :html

  alias PevSquad.Reviews.{PevModel, Review}

  import PevSquadWeb.RiderComponents, only: [type_label: 1]

  def model_name(%PevModel{} = model), do: PevModel.full_name(model)

  @doc "Five-star strip from a 0–10 score (8.5 -> ★★★★☆)."
  def stars(nil), do: ""

  def stars(score) do
    full = round(score / 2)
    String.duplicate("★", full) <> String.duplicate("☆", 5 - full)
  end

  def fmt(nil), do: "—"
  def fmt(score), do: :erlang.float_to_binary(score * 1.0, decimals: 1)

  def author_name(%Review{author_profile: %{alias: alias_name}}), do: alias_name
  def author_name(_review), do: gettext("Deleted rider")

  attr :label, :string, required: true
  attr :score, :float, required: true

  def rating_row(assigns) do
    ~H"""
    <div class="rating-row">
      <span class="rating-label">{@label}</span>
      <div class="rating-bar"><span style={"width:#{round(@score * 10)}%"}></span></div>
      <span class="rating-num">{fmt(@score)}</span>
    </div>
    """
  end

  attr :review, Review, required: true

  def review_card(assigns) do
    ~H"""
    <article class="card">
      <div class="card-head">
        <span class="card-initials">{type_label(@review.pev_model.pev_type)}</span>
      </div>
      <div class="card-body">
        <h3 class="card-title">{model_name(@review.pev_model)}</h3>
        <p class="card-meta">
          {String.upcase(
            type_label(@review.pev_model.pev_type) <>
              " · " <> gettext("reviewed by %{rider}", rider: author_name(@review))
          )}
        </p>
        <div class="stars">{stars(@review.overall)}</div>
        <p class="card-desc">{@review.summary}</p>
        <.rating_row
          :for={{label, score} <- Enum.take(Review.scores(@review), 3)}
          label={label}
          score={score}
        />
        <.link
          navigate={~p"/reviews/#{@review.id}"}
          class="btn btn-outline"
          style="margin-top:1.25rem;"
        >
          {gettext("Read Full Review")}
        </.link>
      </div>
    </article>
    """
  end

  attr :rows, :list, required: true

  def sheet_table(assigns) do
    ~H"""
    <div class="spec-scroll">
      <table class="spec-table">
        <thead>
          <tr>
            <th scope="col">#</th>
            <th scope="col">{gettext("Model")}</th>
            <th scope="col">{gettext("Class")}</th>
            <th scope="col" style="text-align:right;">{gettext("Reviews")}</th>
            <th scope="col" style="text-align:right;">{gettext("Overall")}</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{row, i} <- Enum.with_index(@rows, 1)}>
            <td class="spec-rank">{String.pad_leading(to_string(i), 2, "0")}</td>
            <td class="model">
              <.link navigate={~p"/models/#{row.model.slug}"}>{model_name(row.model)} ≫</.link>
            </td>
            <td>{type_label(row.model.pev_type)}</td>
            <td class="num">{row.reviews}</td>
            <td class="score">{fmt(row.overall)}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
