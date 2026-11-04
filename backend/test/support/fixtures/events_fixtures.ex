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
end
