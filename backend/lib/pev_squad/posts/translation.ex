defmodule PevSquad.Posts.Translation do
  @moduledoc """
  A post's text in one language. The body is Markdown.

  The admin form always shows every language. A language left completely
  blank isn't saved, and blanking out a saved one deletes it.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @locales PevSquadWeb.Locale.supported()

  schema "post_translations" do
    field :locale, :string
    field :title, :string
    field :excerpt, :string
    field :body, :string
    field :machine_translated, :boolean, default: false

    belongs_to :post, PevSquad.Posts.Post

    timestamps(type: :utc_datetime)
  end

  def locales, do: @locales

  @doc false
  def changeset(translation, attrs) do
    changeset =
      translation
      |> cast(attrs, [:locale, :title, :excerpt, :body, :machine_translated])
      |> validate_required([:locale])
      |> validate_inclusion(:locale, @locales)

    if blank?(changeset) do
      %{changeset | action: if(translation.id, do: :delete, else: :ignore)}
    else
      changeset
      |> validate_required([:title, :body])
      |> validate_length(:title, max: 160)
      |> validate_length(:excerpt, max: 300)
      |> unique_constraint([:post_id, :locale])
    end
  end

  defp blank?(changeset) do
    Enum.all?([:title, :excerpt, :body], fn field ->
      case get_field(changeset, field) do
        nil -> true
        value -> String.trim(value) == ""
      end
    end)
  end
end
