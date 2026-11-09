defmodule PevSquad.Accounts.MobileAuth do
  @moduledoc "Expiring app sessions, backed by hashed refresh tokens in users_tokens."
  import Ecto.Query
  alias PevSquad.{Accounts, Repo}
  alias PevSquad.Accounts.{User, UserToken, UserNotifier}

  @salt "mobile-access-v1"
  @access_seconds 900
  @refresh_days 30

  def password(email, password) when is_binary(email) and is_binary(password) do
    case Accounts.get_user_by_email_and_password(String.trim(email), password) do
      %User{confirmed_at: confirmed} = user when not is_nil(confirmed) -> {:ok, issue(user)}
      _ -> {:error, :unauthorized}
    end
  end

  def password(_, _), do: {:error, :unauthorized}

  def request_link(email, locale) when is_binary(email) do
    email = String.trim(email)

    result =
      case Accounts.get_user_by_email(email) do
        nil -> Accounts.register_user(%{"email" => email, "locale" => locale})
        user -> {:ok, user}
      end

    with {:ok, user} <- result do
      # Match the web's protection against confirming an unverified password account.
      unless is_nil(user.confirmed_at) and not is_nil(user.hashed_password) do
        {token, row} = UserToken.build_email_token(user, "app_login")
        Repo.insert!(row)
        UserNotifier.deliver_login_instructions(user, "pevsquad:///auth/confirm?token=" <> token)
      end

      :ok
    end
  end

  def request_link(_, _), do: {:error, {:validation_failed, %{email: ["is required"]}}}

  def exchange(token) do
    with {:ok, hash} <- decode(token) do
      Repo.transaction(fn ->
        row =
          Repo.one(
            from t in UserToken,
              where: t.context == "app_login" and t.token == ^hash,
              where: t.inserted_at > ago(15, "minute"),
              lock: "FOR UPDATE"
          )

        if is_nil(row), do: Repo.rollback(:unauthorized)
        user = Repo.get!(User, row.user_id)

        if row.sent_to != user.email or
             (is_nil(user.confirmed_at) and not is_nil(user.hashed_password)),
           do: Repo.rollback(:unauthorized)

        Repo.delete!(row)
        user = if user.confirmed_at, do: user, else: Repo.update!(User.confirm_changeset(user))
        issue(user)
      end)
    else
      _ -> {:error, :unauthorized}
    end
  end

  def refresh("pevm_r_" <> token) do
    with {:ok, hash} <- decode(token) do
      Repo.transaction(fn ->
        row =
          Repo.one(
            from t in UserToken,
              where: t.context == "refresh" and t.token == ^hash,
              where: t.expires_at > ^DateTime.utc_now(:second),
              lock: "FOR UPDATE"
          )

        if is_nil(row), do: Repo.rollback(:unauthorized)
        user = Repo.get!(User, row.user_id)
        Repo.delete!(row)
        issue(%{user | authenticated_at: row.authenticated_at}, row.expires_at)
      end)
    else
      _ -> {:error, :unauthorized}
    end
  end

  def refresh(_), do: {:error, :unauthorized}

  def revoke("pevm_r_" <> token) do
    with {:ok, hash} <- decode(token) do
      Repo.delete_all(from t in UserToken, where: t.context == "refresh" and t.token == ^hash)
    end

    :ok
  end

  def revoke(_), do: :ok

  def get_user("pevm_a_" <> token) do
    with {:ok, {id, hash}} <-
           Phoenix.Token.verify(PevSquadWeb.Endpoint, @salt, token, max_age: @access_seconds) do
      Repo.one(
        from t in UserToken,
          join: u in assoc(t, :user),
          where: t.id == ^id and t.token == ^hash and t.context == "refresh",
          where: t.expires_at > ^DateTime.utc_now(:second),
          select: %{u | authenticated_at: t.authenticated_at}
      )
    else
      _ -> nil
    end
  end

  def get_user(_), do: nil

  defp issue(user, expires_at \\ nil) do
    now = DateTime.utc_now(:second)
    expires_at = expires_at || DateTime.add(now, @refresh_days, :day)
    {refresh, row} = UserToken.build_email_token(user, "refresh")

    row =
      Repo.insert!(%{
        row
        | expires_at: expires_at,
          authenticated_at: user.authenticated_at || now
      })

    access = Phoenix.Token.sign(PevSquadWeb.Endpoint, @salt, {row.id, row.token})

    %{
      access_token: "pevm_a_" <> access,
      refresh_token: "pevm_r_" <> refresh,
      expires_in: @access_seconds,
      token_type: "Bearer"
    }
  end

  defp decode(token) when is_binary(token) do
    with {:ok, raw} when byte_size(raw) == 32 <- Base.url_decode64(token, padding: false),
         do: {:ok, :crypto.hash(:sha256, raw)}
  end

  defp decode(_), do: :error
end
