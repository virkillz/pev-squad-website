defmodule PevSquadWeb.API.AuthSchemas do
  @moduledoc false
  alias OpenApiSpex.Schema

  def input(required, properties),
    do: %Schema{type: :object, required: required, properties: properties}

  def string, do: %Schema{type: :string}

  def session do
    input([:data], %{
      data:
        input([:access_token, :refresh_token, :expires_in, :token_type], %{
          access_token: string(),
          refresh_token: string(),
          expires_in: %Schema{type: :integer},
          token_type: string()
        })
    })
  end

  def accepted, do: input([:data], %{data: input([:sent], %{sent: %Schema{type: :boolean}})})

  def profile do
    input([:alias, :primary_pev_type], %{
      alias: string(),
      city: string(),
      main_ride: string(),
      bio: string(),
      instagram: string(),
      primary_pev_type: %Schema{type: :string, enum: ~w(euc escooter esk8 ebike other)},
      is_public: %Schema{type: :boolean}
    })
  end
end
