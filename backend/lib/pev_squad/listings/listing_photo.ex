defmodule PevSquad.Listings.ListingPhoto do
  @moduledoc "One processed listing photo, stored inside the listing row."
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :large_path, :string
    field :thumb_path, :string
    field :width, :integer
    field :height, :integer
  end
end
