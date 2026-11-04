defmodule PevSquad.Gallery.PrototypeImport do
  @moduledoc """
  One-off import of the static prototype's gallery.html: each "Album NN"
  section becomes a published album, each tile a published photo (run
  through the normal processing, so files are re-encoded and stripped).
  See `mix pev_squad.import_gallery`.
  """

  import Ecto.Query

  alias PevSquad.Gallery.{Album, Photo, Processing}
  alias PevSquad.Repo

  @doc "Returns `[{album_title, :imported | :skipped, photo_count}]`."
  def run(html_path, admin) do
    root = Path.dirname(html_path)

    html_path
    |> File.read!()
    |> parse()
    # Album 01 is the newest; insert oldest first so ids sort the same way.
    |> Enum.reverse()
    |> Enum.map(&import_album(&1, root, admin))
    |> Enum.reverse()
  end

  @doc false
  def parse(html) do
    ~r{<span class="eyebrow">Album \d+ · (.*?)</span>\s*<h2 class="section-title">(.*?)</h2>(.*?)(?=<span class="eyebrow">Album \d+|<!-- SUBMIT|\z)}s
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(fn [subtitle, title, body] ->
      %{subtitle: unescape(subtitle), title: unescape(title), photos: parse_tiles(body)}
    end)
  end

  defp parse_tiles(body) do
    ~r{<a class="photo-tile(?: t-(big|wide))?" href="([^"]+)"\s+data-title="([^"]*)"\s+data-desc="([^"]*)"\s+data-meta="([^"]*)">.*?<img [^>]*alt="([^"]*)".*?<span class="photo-cap-meta">(.*?)</span>}s
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(fn [size, href, title, desc, _lightbox_meta, alt, cap_meta] ->
      %{
        tile: if(size == "", do: :normal, else: String.to_existing_atom(size)),
        file: href,
        title: blank_to_nil(unescape(title)),
        caption: blank_to_nil(unescape(desc)),
        alt: blank_to_nil(unescape(alt)),
        meta: blank_to_nil(unescape(cap_meta))
      }
    end)
  end

  defp import_album(%{title: title} = data, root, admin) do
    if Repo.exists?(where(Album, title: ^title)) do
      {title, :skipped, 0}
    else
      album =
        %Album{created_by_id: admin.id, published: true}
        |> Album.changeset(%{title: title, subtitle: data.subtitle})
        |> Repo.insert!()

      count =
        data.photos
        |> Enum.with_index(1)
        |> Enum.count(fn {photo, position} ->
          case Processing.store(Path.join(root, photo.file), album.slug) do
            {:ok, files} ->
              %Photo{
                album_id: album.id,
                uploader_id: admin.id,
                status: :published,
                position: position,
                tile: photo.tile,
                meta: photo.meta,
                moderated_by_id: admin.id
              }
              |> Ecto.Changeset.change(files)
              |> Photo.details_changeset(Map.take(photo, [:title, :caption, :alt]))
              |> Repo.insert!()

              true

            {:error, _} ->
              false
          end
        end)

      {title, :imported, count}
    end
  end

  defp unescape(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.trim()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(text), do: text
end
