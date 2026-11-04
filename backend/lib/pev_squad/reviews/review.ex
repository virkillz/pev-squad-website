defmodule PevSquad.Reviews.Review do
  use Ecto.Schema
  import Ecto.Changeset

  alias PevSquad.Reviews.{PevModel, Score}

  @criteria [
    power: "Power",
    range: "Range",
    comfort: "Comfort",
    build: "Build",
    value: "Value",
    app: "App/FW"
  ]

  schema "reviews" do
    field :headline, :string
    field :summary, :string
    field :the_ride, :string
    field :the_catch, :string
    field :km_on_unit, :integer

    field :score_power, Score
    field :score_range, Score
    field :score_comfort, Score
    field :score_build, Score
    field :score_value, Score
    field :score_app, Score
    field :overall, Score

    field :status, Ecto.Enum, values: [:pending, :published, :rejected], default: :pending
    field :rejection_reason, :string
    field :featured, :boolean, default: false
    field :published_at, :utc_datetime

    # Author's rider profile, loaded by Reviews queries for display.
    field :author_profile, :any, virtual: true

    belongs_to :pev_model, PevModel
    belongs_to :author, PevSquad.Accounts.User
    belongs_to :moderated_by, PevSquad.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc "[{:power, \"Power\"}, ...] — the criteria in display order."
  def criteria, do: @criteria

  def score_field(criterion), do: :"score_#{criterion}"

  @doc "[{\"Power\", 9.4}, ...] for the criteria this review scored."
  def scores(%__MODULE__{} = review) do
    for {key, label} <- @criteria, score = Map.get(review, score_field(key)), do: {label, score}
  end

  @required_scores ~w(score_power score_range score_comfort score_build score_value)a

  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :pev_model_id,
      :headline,
      :summary,
      :the_ride,
      :the_catch,
      :km_on_unit,
      :score_app | @required_scores
    ])
    |> validate_required([:pev_model_id, :headline, :summary, :the_ride | @required_scores],
      message: "can't be blank"
    )
    |> validate_length(:headline, max: 60)
    |> validate_length(:summary, max: 280)
    |> validate_length(:the_ride, max: 4000)
    |> validate_length(:the_catch, max: 2000)
    |> validate_number(:km_on_unit, greater_than_or_equal_to: 0, less_than: 1_000_000)
    |> put_overall()
    |> assoc_constraint(:pev_model)
    |> unique_constraint([:pev_model_id, :author_id],
      error_key: :pev_model_id,
      message: "you've already reviewed this model — edit that review instead"
    )
  end

  defp put_overall(changeset) do
    scores =
      for {key, _} <- @criteria,
          score = get_field(changeset, score_field(key)),
          do: score

    put_change(changeset, :overall, Score.average(scores))
  end
end
