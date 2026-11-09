defmodule PevSquad.RidersFixtures do
  @moduledoc "Test helpers for rider profiles and images."

  alias PevSquad.Riders

  def rider_fixture(attrs \\ %{}) do
    {:ok, rider} =
      attrs
      |> Enum.into(%{
        alias: "Rider #{System.unique_integer([:positive])}",
        city: "Jakarta",
        primary_pev_type: :euc,
        main_ride: "Veteran Sherman L",
        is_public: true
      })
      |> Riders.import_rider()

    rider
  end

  @doc """
  A member's own profile, already approved by staff (new member profiles
  start pending). Returns `{:ok, profile}` like `Riders.save_my_profile/2`.
  """
  def approved_profile(scope, attrs) do
    {:ok, profile} = Riders.save_my_profile(scope, attrs)

    Riders.approve_rider(PevSquad.EventsFixtures.staff_scope_fixture(), profile)
  end

  @doc "Writes a plain orange JPEG and returns its path."
  def image_fixture(width \\ 600, height \\ 900) do
    path = Path.join(System.tmp_dir!(), "pev-test-#{System.unique_integer([:positive])}.jpg")
    Image.new!(width, height, color: :orange) |> Image.write!(path)
    path
  end
end
