defmodule PevSquad.Gallery.Processing do
  @moduledoc """
  Turns an uploaded photo into two WebP files — `large` (longest edge
  2048px, for the lightbox) and `thumb` (800px, for grid tiles) — with
  orientation applied and all metadata (EXIF, including GPS) stripped.
  """

  alias PevSquad.Uploads

  @large 2048
  @thumb 800

  def max_bytes, do: 20_000_000

  @doc "Returns `{:ok, %{large_path, thumb_path, width, height}}` (public URLs)."
  def store(source, album_slug) do
    base = "#{album_slug}/#{Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)}"

    with {:ok, image} <- Image.open(source),
         {:ok, {image, _flags}} <- Image.autorotate(image),
         {:ok, large} <- Image.thumbnail(image, @large, resize: :down),
         {:ok, thumb} <- Image.thumbnail(image, @thumb, resize: :down),
         {:ok, large_url} <- write(large, "#{base}.webp"),
         {:ok, thumb_url} <- write(thumb, "#{base}-t.webp") do
      {:ok,
       %{
         large_path: large_url,
         thumb_path: thumb_url,
         width: Image.width(large),
         height: Image.height(large)
       }}
    end
  end

  defp write(image, name) do
    relative = Path.join("gallery", name)
    dest = Uploads.path(relative)
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, _} <- Image.write(image, dest, strip_metadata: true, quality: 82) do
      {:ok, "/uploads/" <> relative}
    end
  end

  @doc "Deletes a photo's files. Ignores paths outside the gallery folder."
  def delete(%{large_path: large, thumb_path: thumb}) do
    for "/uploads/gallery/" <> rest <- [large, thumb] do
      _ = File.rm(Uploads.path(Path.join("gallery", rest)))
    end

    :ok
  end
end
