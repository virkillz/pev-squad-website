defmodule PevSquad.ReviewsFixtures do
  @moduledoc "Test helpers for the model catalog and reviews."

  import PevSquad.EventsFixtures

  alias PevSquad.Reviews

  def model_fixture(attrs \\ %{}) do
    {:ok, model} =
      Reviews.create_model(
        staff_scope_fixture(),
        Enum.into(attrs, %{
          "pev_type" => "euc",
          "brand" => "Kingsong",
          "name" => "S22 Pro #{System.unique_integer([:positive])}"
        })
      )

    model
  end

  def review_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      "headline" => "Most planted wheel",
      "summary" => "Planted at speed; charge time is the knock.",
      "the_ride" => "Suspension soaks up Jakarta's broken asphalt.",
      "the_catch" => "Charge time.",
      "km_on_unit" => "2100",
      "score_power" => "9.4",
      "score_range" => "8.8",
      "score_comfort" => "9.0",
      "score_build" => "8.5",
      "score_value" => "7.4"
    })
  end
end
