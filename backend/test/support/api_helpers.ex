defmodule PevSquadWeb.APIHelpers do
  @moduledoc "Helpers for /api/v1 controller tests."

  import Plug.Conn

  alias PevSquad.Accounts

  @doc "A JSON conn authenticated with a fresh personal API token for `scope`."
  def api_conn(conn, scope) do
    {:ok, token, _} = Accounts.create_api_token(scope, %{"name" => "test"})

    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("authorization", "Bearer " <> token)
  end
end
