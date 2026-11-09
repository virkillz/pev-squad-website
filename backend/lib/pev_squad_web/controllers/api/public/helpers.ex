defmodule PevSquadWeb.API.Public.Helpers do
  @moduledoc "Shared bits for the public read controllers."

  alias PevSquad.Safety

  @doc "Members the caller blocked (their content is left out), or []."
  def hidden_ids(conn), do: Safety.hidden_user_ids(conn.assigns[:current_scope])

  def scope(conn), do: conn.assigns[:current_scope]

  def locale, do: Gettext.get_locale(PevSquadWeb.Gettext)

  @doc "Runs a `get_…!` lookup, turning a miss into `{:error, :not_found}`."
  def fetch(fun) do
    {:ok, fun.()}
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  @doc "An enum query param: `{:ok, atom | nil}` or a validation error."
  def enum_param(params, key, allowed) do
    case params[key] do
      nil ->
        {:ok, nil}

      "" ->
        {:ok, nil}

      value ->
        case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
          nil ->
            {:error,
             {:validation_failed,
              %{key => ["must be one of: " <> Enum.map_join(allowed, ", ", &Atom.to_string/1)]}}}

          atom ->
            {:ok, atom}
        end
    end
  end
end
