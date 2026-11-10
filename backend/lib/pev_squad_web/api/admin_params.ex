defmodule PevSquadWeb.API.AdminParams do
  @moduledoc """
  Turns admin API request bodies into the attrs the contexts expect.

  - The API only writes drafts, so `status` / `published_at` are refused with
    a clear message instead of being silently dropped.
  - Post translations arrive keyed by locale (`{"id": {...}, "en": null}`)
    and are merged into the existing ones, so a PATCH that only sends `en`
    leaves `id` alone. `null` deletes a language.
  - Event times may carry an offset (`2026-11-20T20:00:00+07:00`, `...Z`) or
    be local (`2026-11-20T20:00`), which means the event's own timezone.
  """
  use Gettext, backend: PevSquadWeb.Gettext

  alias PevSquad.Posts.{Post, Translation}
  alias PevSquad.Events.Event

  @post_fields ~w(kind slug topic source_name source_url event_id album_id)
  @event_fields ~w(title slug kind role partners starts_at ends_at timezone location_name
                   meeting_point description capacity rsvp_deadline)
  @event_times ~w(starts_at ends_at rsvp_deadline)
  @publish_fields ~w(status published_at)

  @doc "`{:error, {:validation_failed, fields}}` when the body tries to publish."
  def refuse_publishing(params) do
    case Enum.filter(@publish_fields, &Map.has_key?(params, &1)) do
      [] ->
        :ok

      keys ->
        msg = gettext("publish in /admin; the API only writes drafts")
        {:error, {:validation_failed, Map.new(keys, &{&1, [msg]})}}
    end
  end

  @doc "Attrs for `Posts.create_post/3` or `update_post/4`. `post` is nil on create."
  def post_attrs(params, post \\ nil) do
    attrs = Map.take(params, @post_fields)

    case Map.fetch(params, "translations") do
      :error ->
        {:ok, attrs}

      {:ok, by_locale} when is_map(by_locale) ->
        with :ok <- known_locales(by_locale) do
          {:ok, Map.put(attrs, "translations", merge_translations(by_locale, post))}
        end

      {:ok, _other} ->
        {:error, {:validation_failed, %{"translations" => [locale_map_message()]}}}
    end
  end

  defp known_locales(by_locale) do
    case Map.keys(by_locale) -- Translation.locales() do
      [] -> :ok
      _ -> {:error, {:validation_failed, %{"translations" => [locale_map_message()]}}}
    end
  end

  defp locale_map_message,
    do: gettext("use an object keyed by language, e.g. {\"id\": {...}, \"en\": {...}}")

  defp merge_translations(by_locale, post) do
    existing = if post, do: Map.new(post.translations, &{&1.locale, &1}), else: %{}

    for locale <- Translation.locales(),
        Map.has_key?(by_locale, locale) or Map.has_key?(existing, locale) do
      current = existing[locale]

      case Map.fetch(by_locale, locale) do
        # Untouched: keep it as it is.
        :error ->
          %{"id" => current.id, "locale" => locale}

        # null: blank it, which deletes a saved translation.
        {:ok, nil} ->
          blank = %{"locale" => locale, "title" => "", "excerpt" => "", "body" => ""}
          if current, do: Map.put(blank, "id", current.id), else: blank

        {:ok, fields} when is_map(fields) ->
          fields
          |> Map.take(~w(title excerpt body machine_translated))
          |> Map.put_new("machine_translated", true)
          |> Map.put("locale", locale)
          |> then(fn t -> if current, do: Map.put(t, "id", current.id), else: t end)

        # Anything else gets locale only; the changeset reports what's missing.
        {:ok, _} ->
          %{"locale" => locale}
      end
    end
  end

  @doc "Attrs for `Events.create_event/2` or `update_event/4`. `event` is nil on create."
  def event_attrs(params, event \\ nil) do
    tz = params["timezone"] || (event && event.timezone) || "Asia/Jakarta"

    params
    |> Map.take(@event_fields)
    |> Map.new(fn
      {key, value} when key in @event_times -> {key, to_utc(value, tz)}
      pair -> pair
    end)
  end

  # Offset given: honour it. No offset: local time in the event's zone.
  # Anything unparseable is passed through for the changeset to reject.
  defp to_utc(value, tz) when is_binary(value) and value != "" do
    value = pad_seconds(value)

    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} ->
        DateTime.to_iso8601(dt)

      {:error, :missing_offset} ->
        with {:ok, naive} <- NaiveDateTime.from_iso8601(value),
             {:ok, dt} <- DateTime.from_naive(naive, tz) do
          dt |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_iso8601()
        else
          _ -> value
        end

      _ ->
        value
    end
  end

  defp to_utc(value, _tz), do: value

  defp pad_seconds(<<_::binary-size(16)>> = value), do: value <> ":00"
  defp pad_seconds(value), do: value

  @doc "`{:ok, nil}` (not given), `{:ok, [id]}` or a validation error."
  def partner_ids(params) do
    id_list(params, "partner_ids", gettext("must be a list of partner ids"))
  end

  @doc "`{:ok, nil}` (not given), `{:ok, [id]}` or a validation error."
  def album_ids(params) do
    id_list(params, "album_ids", gettext("must be a list of album ids"))
  end

  defp id_list(params, key, message) do
    case Map.fetch(params, key) do
      :error ->
        {:ok, nil}

      {:ok, ids} when is_list(ids) ->
        if Enum.all?(ids, &is_integer/1),
          do: {:ok, Enum.uniq(ids)},
          else: {:error, {:validation_failed, %{key => [message]}}}

      {:ok, _} ->
        {:error, {:validation_failed, %{key => [message]}}}
    end
  end

  @doc "The API may only change drafts (and only official events)."
  def editable?(%Post{status: :draft}), do: :ok
  def editable?(%Event{status: :draft, category: :official}), do: :ok
  def editable?(_), do: {:error, :conflict}
end
