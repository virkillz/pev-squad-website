defmodule PevSquad.Riders.MemberImport do
  @moduledoc """
  Imports rider profiles from the Google Form export
  ("member pev squad.csv") — see `mix pev_squad.import_members`.

  * Only rows answering "Ya" to *Bersedia dicantumkan di website?* are made
    public; other rows are imported hidden.
  * Bio and ride text come from the prototype's community.html card for the
    same alias when available (the polished English copy); otherwise the
    raw form answer is used.
  * Photos are matched by alias against files in the photos directory
    (`wynn.jpeg` for alias "Wynn").
  """

  NimbleCSV.define(__MODULE__.CSV, separator: ",", escape: "\"")

  alias PevSquad.Riders

  @columns %{
    full_name: "Nama",
    alias: "Alias (yang akan dicantumkan di website)",
    pev_type: "PEV Utama",
    main_ride: "Model PEV yang dipakai (ie. Veteran Sherman L)",
    city: "Kota Domisili",
    bio: "Bio (bakal ditulis ulang pakai AI)",
    consent: "Bersedia dicantumkan di website?"
  }

  @pev_types %{
    "euc" => :euc,
    "e-scooter" => :escooter,
    "escooter" => :escooter,
    "eboard" => :esk8,
    "esk8" => :esk8,
    "ebike" => :ebike,
    "e-bike" => :ebike
  }

  @doc """
  Runs the import. Returns a list of `{status, alias, detail}` tuples where
  status is `:imported`, `:skipped` or `:error`.
  """
  def run(csv_path, opts \\ []) do
    cards = if path = opts[:cards], do: parse_cards(File.read!(path)), else: %{}
    photos = if dir = opts[:photos], do: index_photos(dir), else: %{}

    csv_path
    |> read_rows()
    |> Enum.map(&to_attrs(&1, cards))
    |> Enum.reject(&(&1.alias == ""))
    |> Enum.map(fn attrs ->
      photo = find_photo(photos, attrs.alias)

      case Riders.import_rider(attrs, photo) do
        {:ok, profile} ->
          {:imported, profile.alias, if(photo, do: "with photo", else: "no photo")}

        {:skipped, _} ->
          {:skipped, attrs.alias, "alias already exists"}

        {:error, changeset} ->
          {:error, attrs.alias, inspect(errors(changeset))}
      end
    end)
  end

  defp read_rows(path) do
    [header | rows] =
      path
      |> File.read!()
      |> String.replace_prefix("﻿", "")
      |> __MODULE__.CSV.parse_string(skip_headers: false)

    Enum.map(rows, fn row -> header |> Enum.zip(row) |> Map.new() end)
  end

  defp to_attrs(row, cards) do
    get = fn key -> row |> Map.get(@columns[key], "") |> String.trim() end
    alias_name = get.(:alias)
    card = Map.get(cards, String.downcase(alias_name), %{})

    %{
      alias: alias_name,
      full_name: blank_to_nil(get.(:full_name)),
      city: blank_to_nil(get.(:city)),
      primary_pev_type: Map.get(@pev_types, String.downcase(get.(:pev_type)), :other),
      main_ride: card[:main_ride] || blank_to_nil(get.(:main_ride)),
      bio: card[:bio] || blank_to_nil(get.(:bio)),
      is_public: String.downcase(get.(:consent)) in ["ya", "yes", "y"]
    }
  end

  @doc false
  # %{"wynn" => %{bio: "...", main_ride: "Sherman OG"}} from community.html cards.
  def parse_cards(html) do
    ~r{<h3 class="card-title">(.*?)</h3>\s*<p class="card-meta">(.*?)</p>\s*<p class="card-desc">(.*?)</p>}s
    |> Regex.scan(html, capture: :all_but_first)
    |> Map.new(fn [title, meta, desc] ->
      main_ride =
        case String.split(unescape(meta), " · ", parts: 2) do
          [_city, ride] -> titlecase(ride)
          _ -> nil
        end

      {String.downcase(unescape(title)), %{bio: unescape(desc), main_ride: main_ride}}
    end)
  end

  defp index_photos(dir) do
    dir
    |> File.ls!()
    |> Enum.filter(&(String.downcase(Path.extname(&1)) in ~w(.jpg .jpeg .png .webp)))
    |> Map.new(fn file -> {photo_key(Path.rootname(file)), Path.join(dir, file)} end)
  end

  # "Si Ganteng" -> siganteng.png; "Ben Esk8" -> ben.JPG (first word).
  defp find_photo(photos, alias_name) do
    first_word = alias_name |> String.split() |> List.first("")
    Map.get(photos, photo_key(alias_name)) || Map.get(photos, photo_key(first_word))
  end

  defp photo_key(name), do: name |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "")

  # Card meta is upper-cased by CSS in the prototype but stored upper-case
  # in some cards; keep model names readable.
  defp titlecase(text) do
    if text == String.upcase(text) do
      text
      |> String.split(" ")
      |> Enum.map_join(" ", fn word ->
        if String.length(word) <= 3 or word =~ ~r/\d/, do: word, else: String.capitalize(word)
      end)
    else
      text
    end
  end

  defp unescape(text) do
    text
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
  end
end
