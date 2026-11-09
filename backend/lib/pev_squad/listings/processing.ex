defmodule PevSquad.Listings.Processing do
  @moduledoc """
  Turns an uploaded listing photo into two WebP files, `large` (longest
  edge 1600px) and `thumb` (800px), with orientation applied and all
  metadata stripped. Phone photos often carry GPS coordinates, which would
  give away where the seller lives.
  """

  alias PevSquad.Listings.ListingPhoto
  alias PevSquad.Uploads

  @large 1600
  @thumb 800
  @folder "listings"

  def max_bytes, do: 20_000_000

  @doc "Returns `{:ok, %ListingPhoto{}}` with public URLs, or `{:error, reason}`."
  def store(source) do
    base = Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)

    with {:ok, image} <- Image.open(source),
         {:ok, {image, _flags}} <- Image.autorotate(image),
         {:ok, large} <- Image.thumbnail(image, @large, resize: :down),
         {:ok, thumb} <- Image.thumbnail(image, @thumb, resize: :down),
         {:ok, large_url} <- write(large, "#{base}.webp"),
         {:ok, thumb_url} <- write(thumb, "#{base}-t.webp") do
      {:ok,
       %ListingPhoto{
         large_path: large_url,
         thumb_path: thumb_url,
         width: Image.width(large),
         height: Image.height(large)
       }}
    end
  end

  defp write(image, name) do
    relative = Path.join(@folder, name)
    dest = Uploads.path(relative)
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, _} <- Image.write(image, dest, strip_metadata: true, quality: 82) do
      {:ok, "/uploads/" <> relative}
    end
  end

  @doc "Deletes a photo's files. Ignores paths outside the listings folder."
  def delete(%{large_path: large, thumb_path: thumb}) do
    for "/uploads/listings/" <> rest <- [large, thumb] do
      _ = File.rm(Uploads.path(Path.join(@folder, rest)))
    end

    :ok
  end
end
