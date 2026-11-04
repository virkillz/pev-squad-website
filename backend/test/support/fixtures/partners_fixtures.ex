defmodule PevSquad.PartnersFixtures do
  @moduledoc "Test helpers for partner communities and brand partners."

  import PevSquad.EventsFixtures, only: [staff_scope_fixture: 0]

  def partner_fixture(attrs \\ %{}) do
    {:ok, partner} =
      PevSquad.Partners.create_partner(
        staff_scope_fixture(),
        Enum.into(attrs, %{
          kind: :community,
          name: "Crew #{System.unique_integer([:positive])}",
          region: "Jakarta Selatan",
          vehicle_focus: :euc
        })
      )

    partner
  end
end
