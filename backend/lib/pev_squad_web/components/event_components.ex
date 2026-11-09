defmodule PevSquadWeb.EventComponents do
  @moduledoc """
  Event rows, date blocks and labels, matching the prototype's events page.
  All times are shown in the event's own timezone.
  """
  use PevSquadWeb, :html

  alias PevSquad.Events
  alias PevSquad.Events.Event

  alias PevSquadWeb.Locale

  # Clauses rather than a map so each label is a literal gettext call
  # (extractable) translated in the current locale.
  def kind_label(:ride), do: gettext("Group Ride")
  def kind_label(:night_ride), do: gettext("Night Ride")
  def kind_label(:trail_ride), do: gettext("Trail Ride")
  def kind_label(:tour), do: gettext("Tour")
  def kind_label(:getaway), do: gettext("Weekend Getaway")
  def kind_label(:expedition), do: gettext("Expedition")
  def kind_label(:race), do: gettext("Race")
  def kind_label(:meetup), do: gettext("Meetup")
  def kind_label(:clinic), do: gettext("Clinic")
  def kind_label(:collab), do: gettext("Community Collab")
  def kind_label(:collab_ride), do: gettext("Collab Ride")
  def kind_label(:brand_invite), do: gettext("Brand Invite")
  def kind_label(:brand_activation), do: gettext("Brand Activation")
  def kind_label(:media), do: gettext("Media")
  def kind_label(:exhibition), do: gettext("Exhibition")
  def kind_label(:marshal), do: gettext("Marshal Duty")

  def kind_options, do: Enum.map(Event.kinds(), &{kind_label(&1), &1})
  def group_ride_kind_options, do: Enum.map(Event.group_ride_kinds(), &{kind_label(&1), &1})

  @doc "\"Group ride · hosted by @alias\", or nil for official events."
  def hosted_by(%Event{category: :group_ride, host_alias: nil}), do: gettext("Group ride")

  def hosted_by(%Event{category: :group_ride, host_alias: host}),
    do: gettext("Group ride · hosted by %{host}", host: host)

  def hosted_by(%Event{}), do: nil

  ## Form helpers — datetime-local inputs are in the event's own timezone,
  ## the DB is UTC.

  @datetime_fields ~w(starts_at ends_at rsvp_deadline)

  def timezone_options do
    [
      {"WIB — Jakarta", "Asia/Jakarta"},
      {"WITA — Makassar", "Asia/Makassar"},
      {"WIT — Jayapura", "Asia/Jayapura"}
    ]
  end

  @doc "Converts \"2026-11-15T20:00\" in the chosen zone to UTC ISO 8601."
  def to_utc_params(params) do
    tz = params["timezone"] || "Asia/Jakarta"

    Enum.reduce(@datetime_fields, params, fn field, acc ->
      with value when is_binary(value) and value != "" <- acc[field],
           {:ok, naive} <- NaiveDateTime.from_iso8601(pad_seconds(value)),
           {:ok, dt} <- DateTime.from_naive(naive, tz) do
        Map.put(acc, field, dt |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_iso8601())
      else
        _ -> acc
      end
    end)
  end

  defp pad_seconds(<<_::binary-size(16)>> = value), do: value <> ":00"
  defp pad_seconds(value), do: value

  @doc "The inverse of `to_utc_params/1`, for a datetime-local input's value."
  def local_input_value(%Phoenix.HTML.FormField{value: value}, tz) do
    case value do
      %DateTime{} = dt ->
        dt |> local(tz) |> DateTime.to_naive() |> to_input()

      value when is_binary(value) and value != "" ->
        case DateTime.from_iso8601(value) do
          {:ok, dt, _offset} -> dt |> local(tz) |> DateTime.to_naive() |> to_input()
          _ -> value
        end

      _ ->
        nil
    end
  end

  defp to_input(naive),
    do:
      naive
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.to_iso8601()
      |> String.slice(0, 16)

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
    "#{Locale.strftime(s, "%a %d %b %Y · %H:%M")} #{s.zone_abbr}"
  end

  @doc "\"02 AUG 2026 · GROUP RIDE · BUNDARAN HI, 20:00\" — the home page Next Up line."
  def next_up_meta(%Event{} = event) do
    s = local(event.starts_at, event.timezone)

    [
      Locale.strftime(s, "%d %b %Y"),
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
  def seats_label(%Event{capacity: nil, going_count: going}),
    do: gettext("%{going} going", going: going)

  def seats_label(%Event{capacity: cap, going_count: going, waitlist_count: wait}) do
    base = gettext("%{going} / %{cap} going", going: going, cap: cap)

    if wait > 0,
      do: base <> " · " <> gettext("%{count} waitlist", count: wait),
      else: base
  end

  defp month(%DateTime{} = dt), do: Locale.strftime(dt, "%b")
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc "One event row, as on the prototype's events page."
  attr :event, Event, required: true
  attr :past, :boolean, default: false

  def event_row(assigns) do
    assigns = assign(assigns, :date, date_block(assigns.event))

    ~H"""
    <.link
      navigate={~p"/events/#{@event.slug}"}
      class={["event-row", @past && "past", @event.category == :group_ride && "is-group"]}
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
        <span
          :if={@event.category == :group_ride}
          class="badge badge-host"
          style="margin-left:0.35rem;"
        >
          {hosted_by(@event)}
        </span>
        <span :if={@event.status == :cancelled} class="badge" style="margin-left:0.35rem;">
          {gettext("Cancelled")}
        </span>
        <h3 class="event-title">{@event.title}</h3>
        <p :if={@event.description} class="event-desc">{excerpt(@event.description)}</p>
        <p
          :if={!@past}
          class="event-desc"
          style="margin-top:0.6rem; font-family:var(--font-mono); font-size:0.75rem; letter-spacing:0.08em; text-transform:uppercase;"
        >
          {Enum.join(Enum.reject([@event.location_name, seats_label(@event)], &is_nil/1), " · ")}
          <span :if={Events.seats_left(@event) == 0}> ·  {gettext("Full — join the waitlist")}</span>
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
