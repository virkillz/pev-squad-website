defmodule PevSquad.Partners.Logo do
  @moduledoc """
  Normalises partner logos: fitted inside 600×600 without cropping (logos
  come in every shape), WebP with transparency kept, metadata stripped.
  """

  alias PevSquad.Uploads

  @size 600
  @max_bytes 5_000_000

  def max_bytes, do: @max_bytes

  @doc "Returns `{:ok, \"/uploads/logos/<slug>-<rand>.webp\"}`."
  def store(source, slug) do
    name = "#{slug}-#{Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)}.webp"
    relative = Path.join("logos", name)
    dest = Uploads.path(relative)
    File.mkdir_p!(Path.dirname(dest))

    with {:ok, image} <- Image.open(source),
         {:ok, thumb} <- Image.thumbnail(image, @size, resize: :down),
         {:ok, _} <- Image.write(thumb, dest, strip_metadata: true, quality: 90) do
      {:ok, "/uploads/" <> relative}
    end
  end

  @doc "Deletes a previously stored logo. Ignores paths we don't own."
  def delete("/uploads/logos/" <> name) do
    _ = File.rm(Uploads.path(Path.join("logos", Path.basename(name))))
    :ok
  end

  def delete(_path), do: :ok
end
