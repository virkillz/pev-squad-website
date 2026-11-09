defmodule PevSquad.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias PevSquad.Repo

  alias PevSquad.Accounts.{Scope, User, UserToken, UserNotifier}
  alias PevSquad.Riders.RiderProfile

  ## Database getters

  @doc "Emails of moderators and admins, for staff notifications."
  def list_staff_emails do
    User
    |> where([u], u.role in [:moderator, :admin])
    |> select([u], u.email)
    |> Repo.all()
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Sets a user's role (`:member`, `:moderator` or `:admin`).

  Not exposed in the UI yet; run `mix pev_squad.set_role EMAIL ROLE`.
  """
  def set_user_role(%User{} = user, role) when role in [:member, :moderator, :admin] do
    user |> Ecto.Changeset.change(role: role) |> Repo.update()
  end

  ## Staff: the member list

  @doc """
  Every account with its rider profile (or nil), newest first, for staff.
  Returns `[%{user: user, profile: profile_or_nil}]`. Options:

  * `:search` — part of the email or the rider alias
  * `:profile` — `:with` or `:without` a rider profile
  """
  def list_members(%Scope{} = scope, opts \\ []) do
    ensure_staff!(scope)

    from(u in User,
      left_join: p in RiderProfile,
      on: p.user_id == u.id,
      order_by: [desc: u.inserted_at, desc: u.id],
      select: %{user: u, profile: p}
    )
    |> filter_profile(opts[:profile])
    |> search_members(opts[:search])
    |> Repo.all()
  end

  defp filter_profile(query, :with), do: where(query, [_u, p], not is_nil(p.id))
  defp filter_profile(query, :without), do: where(query, [_u, p], is_nil(p.id))
  defp filter_profile(query, _), do: query

  defp search_members(query, term) when term in [nil, ""], do: query

  defp search_members(query, term) do
    pattern = "%" <> String.replace(String.trim(term), ~r/[\\%_]/, "\\\\\\0") <> "%"
    where(query, [u, p], ilike(u.email, ^pattern) or ilike(p.alias, ^pattern))
  end

  @doc """
  Changes another member's role. Admins only, and never their own role,
  so the last admin can't lock everyone out by accident.
  """
  def change_role(%Scope{user: me} = scope, %User{} = user, role)
      when role in [:member, :moderator, :admin] do
    cond do
      not Scope.admin?(scope) -> raise PevSquad.Accounts.NotAuthorizedError
      user.id == me.id -> {:error, :own_role}
      true -> set_user_role(user, role)
    end
  end

  ## Admin: deleting a member

  @doc """
  What deleting `user` would remove, for the confirmation screen:
  `%{profile, keeps_profile?, reviews, photos, hosted_rides, upcoming_rsvps}`.
  """
  def member_footprint(%Scope{} = scope, %User{id: user_id} = user) do
    ensure_staff!(scope)
    profile = Repo.get_by(RiderProfile, user_id: user_id)
    now = DateTime.utc_now()

    %{
      user: user,
      profile: profile,
      keeps_profile?: profile != nil and profile.source != :member,
      reviews: count(PevSquad.Reviews.Review, author_id: user_id),
      photos: count(PevSquad.Gallery.Photo, uploader_id: user_id),
      hosted_rides: count(PevSquad.Events.Event, created_by_id: user_id, category: :group_ride),
      upcoming_rsvps:
        from(r in PevSquad.Events.Rsvp,
          join: e in assoc(r, :event),
          where: r.user_id == ^user_id and e.starts_at > ^now
        )
        |> Repo.aggregate(:count)
    }
  end

  defp count(schema, clauses), do: schema |> where(^clauses) |> Repo.aggregate(:count)

  @doc """
  Deletes a member's account and what they posted. Admins only; never
  yourself or another admin (change their role first).

  * upcoming RSVPs are cancelled first, so the waitlist moves up
    (`event_url_fun` builds the link in the "you're in" email)
  * group rides they hosted are removed; riders signed up for an upcoming
    one get the cancellation email, linking to `events_url`
  * gallery photos and their files are deleted
  * a profile they made themselves is deleted; an imported or staff-added
    one is kept, unclaimed, so the roster keeps its history
  * reviews, RSVPs, tokens and blocks go with the account

  Returns `{:ok, user}`, `{:error, :self}` or `{:error, :admin}`.
  """
  def delete_member(%Scope{user: me} = scope, %User{} = user, event_url_fun, events_url) do
    cond do
      not Scope.admin?(scope) -> raise PevSquad.Accounts.NotAuthorizedError
      user.id == me.id -> {:error, :self}
      user.role == :admin -> {:error, :admin}
      true -> do_delete_member(scope, user, event_url_fun, events_url)
    end
  end

  defp do_delete_member(scope, user, event_url_fun, events_url) do
    alias PevSquad.Events.{Event, Rsvp}
    alias PevSquad.Events.Notifier, as: EventNotifier

    now = DateTime.utc_now()
    member_scope = Scope.for_user(user)

    # 1. Free their seats on upcoming events through the normal path.
    from(r in Rsvp,
      join: e in assoc(r, :event),
      where: r.user_id == ^user.id and e.starts_at > ^now,
      select: e
    )
    |> Repo.all()
    |> Enum.each(&PevSquad.Events.cancel_rsvp(member_scope, &1, event_url_fun))

    # 2. Remove the group rides they hosted, telling anyone still signed up.
    for ride <-
          Repo.all(
            from e in Event, where: e.created_by_id == ^user.id and e.category == :group_ride
          ) do
      if ride.status == :published and DateTime.after?(ride.starts_at, now) do
        from(r in Rsvp, where: r.event_id == ^ride.id and r.user_id != ^user.id, preload: :user)
        |> Repo.all()
        |> Enum.each(&EventNotifier.deliver_event_cancelled(&1.user, ride, events_url))
      end

      Repo.delete!(ride)
    end

    # 3. Gallery photos, files included.
    for photo <- Repo.all(from p in PevSquad.Gallery.Photo, where: p.uploader_id == ^user.id) do
      {:ok, _} = PevSquad.Gallery.delete_photo(scope, photo)
    end

    # 4. Their own profile goes; imported or staff-added ones become unclaimed
    #    when the account is deleted (rider_profiles.user_id is nilified).
    case Repo.get_by(RiderProfile, user_id: user.id, source: :member) do
      nil -> :ok
      profile -> {:ok, _} = PevSquad.Riders.delete_rider(scope, profile)
    end

    # 5. The account; reviews, RSVPs, tokens and blocks cascade.
    Repo.delete(user)
  end

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Accounts.NotAuthorizedError)
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `PevSquad.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `PevSquad.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end

defmodule PevSquad.Accounts.NotAuthorizedError do
  defexception message: "not allowed to manage members", plug_status: 403
end
