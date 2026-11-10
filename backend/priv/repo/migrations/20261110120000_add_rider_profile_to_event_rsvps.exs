defmodule PevSquad.Repo.Migrations.AddRiderProfileToEventRsvps do
  use Ecto.Migration

  def change do
    # Staff can put riders without an account on an event's list. Such an
    # RSVP points at the (unclaimed) rider profile instead of a user; when
    # the profile is claimed it moves to the user. Exactly one is set.
    alter table(:event_rsvps) do
      add :rider_profile_id, references(:rider_profiles, on_delete: :delete_all)
      modify :user_id, :bigint, null: true, from: {:bigint, null: false}
    end

    create unique_index(:event_rsvps, [:event_id, :rider_profile_id],
             where: "rider_profile_id IS NOT NULL"
           )

    create constraint(:event_rsvps, :user_or_rider_profile,
             check: "(user_id IS NULL) <> (rider_profile_id IS NULL)"
           )
  end
end
