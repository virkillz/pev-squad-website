defmodule PevSquad.Posts.Images do
  @moduledoc """
  Cover images and inline images for posts: longest edge 1600px, WebP,
  orientation applied and metadata (EXIF, GPS) stripped.
  """

  alias PevSquad.Uploads

  @size 1600
  @max_bytes 15_000_000

  def max_bytes, do: @max_bytes

  @doc "Returns `{:ok, \"/uploads/posts/<prefix>-<rand>.webp\"}`."
  def store(source, prefix) do
    name = "#{prefix}-#{Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)}.webp"
    relative = Path.join("posts", name)
    dest = Uploads.path(relative)
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, image} <- Image.open(source),
         {:ok, {image, _flags}} <- Image.autorotate(image),
         {:ok, resized} <- Image.thumbnail(image, @size, resize: :down),
         {:ok, _} <- Image.write(resized, dest, strip_metadata: true, quality: 82) do
      {:ok, "/uploads/" <> relative}
    end
  end

  @doc "Deletes a stored image. Ignores paths outside the posts folder."
  def delete("/uploads/posts/" <> name) do
    _ = File.rm(Uploads.path(Path.join("posts", Path.basename(name))))
    :ok
  end

  def delete(_path), do: :ok
end
