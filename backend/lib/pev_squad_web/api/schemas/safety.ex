defmodule PevSquadWeb.API.Schemas.Safety do
  @moduledoc false
  alias OpenApiSpex.Schema

  def target_props do
    %{
      target_type: %Schema{type: :string, enum: ~w(profile photo event review)},
      target_id: %Schema{type: :integer}
    }
  end

  def blocked_member, do: obj(%{user_id: int(), alias: %Schema{type: :string, nullable: true}})

  def obj(props, required \\ nil),
    do: %Schema{type: :object, properties: props, required: required || Map.keys(props)}

  def list(item), do: %Schema{type: :array, items: item}
  def enum(values), do: %Schema{type: :string, enum: Enum.map(values, &to_string/1)}
  def str, do: %Schema{type: :string}
  def int, do: %Schema{type: :integer}
  def bool, do: %Schema{type: :boolean}
end
