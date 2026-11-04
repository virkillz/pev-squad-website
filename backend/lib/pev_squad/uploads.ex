defmodule PevSquad.Uploads do
  @moduledoc """
  Where user-uploaded files live on disk, served at `/uploads`.

  Local disk for now (`priv/uploads` in dev, `UPLOADS_DIR` in prod — a
  persistent volume on the VPS). Moves to R2/Spaces with the media pipeline.
  """

  def dir do
    Application.get_env(:pev_squad, :uploads_dir) ||
      Path.join(:code.priv_dir(:pev_squad), "uploads")
  end

  def path(relative), do: Path.join(dir(), relative)
end
