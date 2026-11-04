defmodule PevSquad.EventsFixtures do
  @moduledoc """
  Test helpers for creating events and staff scopes.
  """

  import PevSquad.AccountsFixtures

  alias PevSquad.Accounts
  alias PevSquad.Accounts.Scope

  def staff_scope_fixture(role \\ :moderator) do
    {:ok, user} = Accounts.set_user_role(user_fixture(), role)
    Scope.for_user(user)
  end

  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      PevSquad.Events.create_event(
        staff_scope_fixture(),
        Enum.into(attrs, %{
          title: "Night Loop #{System.unique_integer([:positive])}",
          kind: :night_ride,
          status: :published,
          starts_at: DateTime.add(DateTime.utc_now(:second), 7, :day),
          location_name: "Jakarta"
        })
      )

    event
  end

  @doc "A member with a public rider profile, so they can host group rides."
  def host_scope_fixture(alias_name \\ nil) do
    scope = user_scope_fixture()

    {:ok, _profile} =
      PevSquad.Riders.save_my_profile(scope, %{
        alias: alias_name || "Host #{System.unique_integer([:positive])}",
        primary_pev_type: :euc,
        is_public: true
      })

    scope
  end

  def group_ride_fixture(scope, attrs \\ %{}) do
    {:ok, ride} =
      PevSquad.Events.create_group_ride(
        scope,
        Enum.into(attrs, %{
          title: "Sunday Loop",
          kind: :ride,
          capacity: 10,
          starts_at: DateTime.add(DateTime.utc_now(:second), 3, :day),
          location_name: "Senayan, Jakarta"
        })
      )

    ride
  end
end
