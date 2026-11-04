defmodule PevSquad.Riders.Avatar do
  @moduledoc """
  Normalises rider photos: 4:5 portrait (800×1000, matching the card photo frame), WebP, cropped around the most interesting region, with all
  metadata (EXIF, including GPS location) stripped.
  """

  alias PevSquad.Uploads

  @size "800x1000"
  @max_bytes 10_000_000

  def max_bytes, do: @max_bytes

  @doc """
  Processes the image at `source` and stores it for the profile `slug`.
  Returns `{:ok, "/uploads/avatars/<slug>-<rand>.webp"}`.
  """
  def store(source, slug) do
    name = "#{slug}-#{Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)}.webp"
    relative = Path.join("avatars", name)
    dest = Uploads.path(relative)
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, image} <- Image.open(source),
         {:ok, image} <- Image.autorotate(image) |> unwrap_autorotate(),
         {:ok, thumb} <- Image.thumbnail(image, @size, crop: :attention),
         {:ok, _} <- Image.write(thumb, dest, strip_metadata: true, quality: 82) do
      {:ok, "/uploads/" <> relative}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Image.autorotate returns {:ok, {image, flags}}.
  defp unwrap_autorotate({:ok, {image, _flags}}), do: {:ok, image}
  defp unwrap_autorotate(other), do: other

  @doc "Deletes a previously stored avatar. Ignores paths we don't own."
  def delete("/uploads/avatars/" <> name) do
    _ = File.rm(Uploads.path(Path.join("avatars", Path.basename(name))))
    :ok
  end

  def delete(_path), do: :ok
end
