defmodule PevSquadWeb.API.AuthController do
  use PevSquadWeb, :api_controller
  alias PevSquad.Accounts.MobileAuth
  alias PevSquadWeb.API.AuthSchemas, as: S

  tags(["App auth"])
  plug PevSquadWeb.API.AuthLimiter when action in [:password, :request_link, :exchange]

  operation(:password,
    summary: "Sign in with an existing confirmed account's password",
    request_body:
      {"Credentials", "application/json",
       S.input([:email, :password], %{email: S.string(), password: S.string()}), required: true},
    responses: [ok: {"App session", "application/json", S.session()}]
  )

  def password(conn, params) do
    with {:ok, session} <- MobileAuth.password(params["email"], params["password"]),
         do: session(conn, session)
  end

  operation(:request_link,
    summary: "Email an app login link, registering a new email if necessary",
    request_body:
      {"Email", "application/json", S.input([:email], %{email: S.string()}), required: true},
    responses: [accepted: {"Instructions sent", "application/json", S.accepted()}]
  )

  def request_link(conn, params) do
    with :ok <- MobileAuth.request_link(params["email"], Gettext.get_locale(PevSquadWeb.Gettext)) do
      conn |> put_status(:accepted) |> json(%{data: %{sent: true}})
    end
  end

  operation(:exchange,
    summary: "Consume a single-use app email token",
    request_body:
      {"Token", "application/json", S.input([:token], %{token: S.string()}), required: true},
    responses: [ok: {"App session", "application/json", S.session()}]
  )

  def exchange(conn, params) do
    with {:ok, session} <- MobileAuth.exchange(params["token"]), do: session(conn, session)
  end

  operation(:refresh,
    summary: "Rotate a refresh token; the previous token and access token stop working",
    request_body:
      {"Refresh token", "application/json",
       S.input([:refresh_token], %{refresh_token: S.string()}), required: true},
    responses: [ok: {"App session", "application/json", S.session()}]
  )

  def refresh(conn, params) do
    with {:ok, session} <- MobileAuth.refresh(params["refresh_token"]), do: session(conn, session)
  end

  operation(:logout,
    summary: "Revoke this app session (idempotent)",
    request_body:
      {"Refresh token", "application/json",
       S.input([:refresh_token], %{refresh_token: S.string()}), required: true},
    responses: [no_content: "Logged out"]
  )

  def logout(conn, params) do
    :ok = MobileAuth.revoke(params["refresh_token"])
    send_resp(conn, :no_content, "")
  end

  defp session(conn, session),
    do: conn |> put_resp_header("cache-control", "no-store") |> json(%{data: session})
end
