defmodule PevSquad.Posts.Images do
  @moduledoc """
  Cover images and inline images for posts, and event covers: longest edge
  1600px, WebP, orientation applied and metadata (EXIF, GPS) stripped.
  Stored under `uploads/posts` or `uploads/events`.
  """

  alias PevSquad.Uploads

  @size 1600
  @max_bytes 15_000_000

  def max_bytes, do: @max_bytes

  @folders ~w(posts events)

  @doc "Returns `{:ok, \"/uploads/<folder>/<prefix>-<rand>.webp\"}`."
  def store(source, prefix, folder \\ "posts") when folder in @folders do
    name = "#{prefix}-#{Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)}.webp"
    relative = Path.join(folder, name)
    dest = Uploads.path(relative)
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, image} <- Image.open(source),
         {:ok, {image, _flags}} <- Image.autorotate(image),
         {:ok, resized} <- Image.thumbnail(image, @size, resize: :down),
         {:ok, _} <- Image.write(resized, dest, strip_metadata: true, quality: 82) do
      {:ok, "/uploads/" <> relative}
    end
  end

  @doc "Deletes a stored image. Ignores paths outside the posts and events folders."
  def delete("/uploads/" <> rest) do
    case Path.split(rest) do
      [folder, name] when folder in @folders ->
        _ = File.rm(Uploads.path(Path.join(folder, name)))
        :ok

      _ ->
        :ok
    end
  end

  def delete(_path), do: :ok
end
