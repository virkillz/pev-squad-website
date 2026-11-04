defmodule PevSquadWeb.EventComponents do
  @moduledoc """
  Event rows, date blocks and labels, matching the prototype's events page.
  All times are shown in the event's own timezone.
  """
  use PevSquadWeb, :html

  alias PevSquad.Events
  alias PevSquad.Events.Event

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @kind_labels %{
    ride: "Group Ride",
    night_ride: "Night Ride",
    trail_ride: "Trail Ride",
    tour: "Tour",
    getaway: "Weekend Getaway",
    expedition: "Expedition",
    race: "Race",
    meetup: "Meetup",
    clinic: "Clinic",
    collab: "Community Collab",
    collab_ride: "Collab Ride",
    brand_invite: "Brand Invite",
    brand_activation: "Brand Activation",
    media: "Media",
    exhibition: "Exhibition",
    marshal: "Marshal Duty"
  }

  def kind_label(kind), do: Map.fetch!(@kind_labels, kind)

  def kind_options, do: Enum.map(Event.kinds(), &{kind_label(&1), &1})

  def local(nil, _tz), do: nil
  def local(%DateTime{} = dt, tz), do: DateTime.shift_zone!(dt, tz)

  @doc """
  Day / month / year for the date block. Multi-day events show a range
  ("18–19 Apr", or "30–02 Oct–Nov" across a month boundary).
  """
  def date_block(%Event{starts_at: starts_at, ends_at: ends_at, timezone: tz}) do
    s = local(starts_at, tz)
    e = local(ends_at, tz)

    cond do
      is_nil(e) or Date.compare(DateTime.to_date(s), DateTime.to_date(e)) == :eq ->
        %{d: pad(s.day), m: month(s), y: s.year, range?: false}

      s.month == e.month ->
        %{d: "#{pad(s.day)}–#{pad(e.day)}", m: month(s), y: s.year, range?: true}

      true ->
        %{d: "#{pad(s.day)}–#{pad(e.day)}", m: "#{month(s)}–#{month(e)}", y: e.year, range?: true}
    end
  end

  @doc "\"Sat 02 Aug 2026 · 20:00 WIB\""
  def when_label(%Event{starts_at: starts_at, timezone: tz}) do
    s = local(starts_at, tz)
    "#{Calendar.strftime(s, "%a %d %b %Y · %H:%M")} #{s.zone_abbr}"
  end

  @doc "\"02 AUG 2026 · GROUP RIDE · BUNDARAN HI, 20:00\" — the home page Next Up line."
  def next_up_meta(%Event{} = event) do
    s = local(event.starts_at, event.timezone)

    [
      Calendar.strftime(s, "%d %b %Y"),
      kind_label(event.kind),
      Enum.join(
        Enum.reject(
          [event.meeting_point || event.location_name, Calendar.strftime(s, "%H:%M")],
          &is_nil/1
        ),
        ", "
      )
    ]
    |> Enum.join(" · ")
    |> String.upcase()
  end

  @doc "\"12 / 20 going · 3 waitlist\", \"8 going\" for unlimited events."
  def seats_label(%Event{capacity: nil, going_count: going}), do: "#{going} going"

  def seats_label(%Event{capacity: cap, going_count: going, waitlist_count: wait}) do
    base = "#{going} / #{cap} going"
    if wait > 0, do: "#{base} · #{wait} waitlist", else: base
  end

  defp month(%DateTime{month: m}), do: Enum.at(@months, m - 1)
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc "One event row, as on the prototype's events page."
  attr :event, Event, required: true
  attr :past, :boolean, default: false

  def event_row(assigns) do
    assigns = assign(assigns, :date, date_block(assigns.event))

    ~H"""
    <.link
      navigate={~p"/events/#{@event.slug}"}
      class={["event-row", @past && "past"]}
      style="text-decoration:none;"
    >
      <div class="event-date">
        <div class={["event-d", @date.range? && "is-range"]}>{@date.d}</div>
        <div class="event-m">{@date.m}</div>
        <div class="event-y">{@date.y}</div>
      </div>
      <div>
        <span
          class={["badge", @past && "badge-grey"]}
          style={@past && "color:var(--black); border-color:var(--black);"}
        >
          {kind_label(@event.kind)}
        </span>
        <span :if={@event.status == :cancelled} class="badge" style="margin-left:0.35rem;">
          Cancelled
        </span>
        <h3 class="event-title">{@event.title}</h3>
        <p :if={@event.description} class="event-desc">{excerpt(@event.description)}</p>
        <p
          :if={!@past}
          class="event-desc"
          style="margin-top:0.6rem; font-family:var(--font-mono); font-size:0.75rem; letter-spacing:0.08em; text-transform:uppercase;"
        >
          {Enum.join(Enum.reject([@event.location_name, seats_label(@event)], &is_nil/1), " · ")}
          <span :if={Events.seats_left(@event) == 0}> · Full — join the waitlist</span>
        </p>
      </div>
    </.link>
    """
  end

  defp excerpt(text) do
    first = text |> String.split(~r/\n\s*\n/, parts: 2) |> hd()
    if String.length(first) > 260, do: String.slice(first, 0, 257) <> "…", else: first
  end
end
