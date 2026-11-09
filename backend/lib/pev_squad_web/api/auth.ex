defmodule PevSquadWeb.API.Auth do
  @moduledoc """
  Bearer-token authentication for `/api/v1`.

  `fetch_api_scope/2` runs in the `:api` pipeline: it reads
  `Authorization: Bearer <token>` and assigns `:current_scope` (nil when the
  header is missing or the token is unknown, expired or not a staff token).
  Routes that need a caller add `require_api_user` or `require_api_staff`.

  Today only personal API tokens (`pevsq_…`, DESIGN.md §7.2) exist. The app's
  access tokens will be checked here too, so controllers keep seeing a plain
  `%Scope{}` whatever the token type.
  """
  import Plug.Conn

  alias PevSquad.Accounts
  alias PevSquad.Accounts.Scope
  alias PevSquadWeb.API.Errors

  def fetch_api_scope(conn, _opts) do
    user =
      case bearer_token(conn) do
        nil -> nil
        token -> Accounts.MobileAuth.get_user(token) || Accounts.get_user_by_api_token(token)
      end

    assign(conn, :current_scope, Scope.for_user(user))
  end

  def require_api_user(%{assigns: %{current_scope: %Scope{}}} = conn, _opts), do: conn

  def require_api_user(conn, _opts) do
    conn
    |> put_resp_header("www-authenticate", ~s(Bearer realm="pev-squad"))
    |> Errors.send_error(:unauthorized)
    |> halt()
  end

  def require_api_staff(conn, opts) do
    conn = require_api_user(conn, opts)

    cond do
      conn.halted -> conn
      Scope.staff?(conn.assigns.current_scope) -> conn
      true -> conn |> Errors.send_error(:forbidden) |> halt()
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      [header | _] ->
        case String.split(header, " ", parts: 2) do
          [scheme, token] ->
            if String.downcase(scheme) == "bearer", do: String.trim(token)

          _ ->
            nil
        end

      [] ->
        nil
    end
  end
end
