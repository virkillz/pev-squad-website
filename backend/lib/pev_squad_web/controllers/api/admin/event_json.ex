defmodule PevSquadWeb.API.Admin.EventJSON do
  use PevSquadWeb, :verified_routes

  def index(%{events: events}), do: %{data: Enum.map(events, &data(&1, nil))}

  def show(%{event: event, partner_ids: partner_ids}), do: %{data: data(event, partner_ids)}

  defp data(event, partner_ids) do
    base = %{
      id: event.id,
      slug: event.slug,
      title: event.title,
      kind: event.kind,
      role: event.role,
      category: event.category,
      status: event.status,
      timezone: event.timezone,
      starts_at: event.starts_at,
      ends_at: event.ends_at,
      rsvp_deadline: event.rsvp_deadline,
      local: %{
        starts_at: local(event.starts_at, event.timezone),
        ends_at: local(event.ends_at, event.timezone),
        rsvp_deadline: local(event.rsvp_deadline, event.timezone)
      },
      location_name: event.location_name,
      meeting_point: event.meeting_point,
      description: event.description,
      capacity: event.capacity,
      partners: event.partners,
      going_count: event.going_count,
      waitlist_count: event.waitlist_count,
      host_alias: event.host_alias,
      url: url(~p"/events/#{event.slug}"),
      admin_url: url(~p"/admin/events/#{event.id}/edit")
    }

    if partner_ids, do: Map.put(base, :partner_ids, partner_ids), else: base
  end

  defp local(nil, _tz), do: nil
  defp local(dt, tz), do: dt |> DateTime.shift_zone!(tz) |> DateTime.to_iso8601()
end
