defmodule PevSquad.Riders do
  @moduledoc """
  Rider profiles — the public face of a member (alias, city, ride, bio,
  photo). Profiles exist independently of accounts: ones imported from the
  old sign-up form start unclaimed (`user_id` nil) until staff link them to
  a member's account.

  Only profiles with `is_public: true` (the rider's consent) are ever shown
  on the public site.
  """

  import Ecto.Query, warn: false

  alias PevSquad.Accounts
  alias PevSquad.Accounts.Scope
  alias PevSquad.Repo
  alias PevSquad.Riders.{Avatar, RiderProfile}

  ## Public

  @doc "Public profiles, optionally filtered by `:type` or `featured: true`. Photos first, then by alias."
  def list_public_riders(opts \\ []) do
    RiderProfile
    |> where(is_public: true)
    |> filter_type(opts[:type])
    |> filter_featured(opts[:featured])
    |> order_by([r], asc: is_nil(r.avatar_path), asc: fragment("lower(?)", r.alias))
    |> Repo.all()
  end

  defp filter_featured(query, true), do: where(query, [r], not is_nil(r.featured_since))
  defp filter_featured(query, _), do: query

  defp filter_type(query, nil), do: query
  defp filter_type(query, type), do: where(query, primary_pev_type: ^type)

  def get_public_rider!(slug), do: Repo.get_by!(RiderProfile, slug: slug, is_public: true)

  @doc "Counts for the community stat bar."
  def stats do
    public = where(RiderProfile, is_public: true)

    %{
      riders: Repo.aggregate(public, :count),
      cities:
        public
        |> where([r], not is_nil(r.city))
        |> select([r], count(fragment("DISTINCT lower(?)", r.city)))
        |> Repo.one()
    }
  end

  ## The current member's own profile

  def get_my_profile(%Scope{user: user}), do: Repo.get_by(RiderProfile, user_id: user.id)

  def change_profile(%RiderProfile{} = profile, attrs \\ %{}),
    do: RiderProfile.changeset(profile, attrs)

  @doc """
  Creates or updates the current member's profile. `avatar_source`, when
  given, is a path to an uploaded image file.
  """
  def save_my_profile(%Scope{user: user} = scope, attrs, avatar_source \\ nil) do
    profile = get_my_profile(scope) || %RiderProfile{user_id: user.id, source: :member}

    profile
    |> RiderProfile.changeset(attrs)
    |> Repo.insert_or_update()
    |> attach_avatar(avatar_source)
  end

  ## Staff

  def list_all_riders(%Scope{} = scope) do
    ensure_staff!(scope)

    RiderProfile
    |> order_by([r], asc: fragment("lower(?)", r.alias))
    |> preload(:user)
    |> Repo.all()
  end

  def get_rider!(%Scope{} = scope, id) do
    ensure_staff!(scope)
    RiderProfile |> Repo.get!(id) |> Repo.preload(:user)
  end

  def update_rider(%Scope{} = scope, %RiderProfile{} = profile, attrs, avatar_source \\ nil) do
    ensure_staff!(scope)

    profile
    |> RiderProfile.staff_changeset(attrs)
    |> Repo.update()
    |> attach_avatar(avatar_source)
  end

  @doc """
  Links an unclaimed (imported) profile to the member with `email`.
  Fails if the member already has a profile or the profile is claimed.
  """
  def link_to_member(%Scope{} = scope, %RiderProfile{} = profile, email) do
    ensure_staff!(scope)

    user = Accounts.get_user_by_email(String.trim(email || ""))

    cond do
      profile.user_id -> {:error, :already_claimed}
      is_nil(user) -> {:error, :no_such_user}
      Repo.get_by(RiderProfile, user_id: user.id) -> {:error, :member_has_profile}
      true -> profile |> Ecto.Changeset.change(user_id: user.id) |> Repo.update()
    end
  end

  def unlink_member(%Scope{} = scope, %RiderProfile{} = profile) do
    ensure_staff!(scope)
    profile |> Ecto.Changeset.change(user_id: nil) |> Repo.update()
  end

  def set_featured(%Scope{} = scope, %RiderProfile{} = profile, featured?) do
    ensure_staff!(scope)
    featured_since = if featured?, do: profile.featured_since || DateTime.utc_now(:second)
    profile |> Ecto.Changeset.change(featured_since: featured_since) |> Repo.update()
  end

  defp ensure_staff!(scope) do
    unless Scope.staff?(scope), do: raise(PevSquad.Riders.NotAuthorizedError)
  end

  ## Import (mix pev_squad.import_members)

  @doc """
  Inserts an imported profile unless one with the same alias exists.
  Returns `{:ok, profile}`, `{:skipped, existing}` or `{:error, changeset}`.
  """
  def import_rider(attrs, avatar_source \\ nil) do
    alias_name = attrs |> Map.get(:alias, "") |> String.trim()

    case Repo.get_by(RiderProfile, alias: alias_name) do
      %RiderProfile{} = existing ->
        {:skipped, existing}

      nil ->
        %RiderProfile{source: :import}
        |> RiderProfile.changeset(attrs)
        |> Repo.insert()
        |> attach_avatar(avatar_source)
    end
  end

  ## Avatars

  defp attach_avatar({:ok, profile}, nil), do: {:ok, profile}

  defp attach_avatar({:ok, profile}, source) do
    case Avatar.store(source, profile.slug) do
      {:ok, path} ->
        old = profile.avatar_path
        {:ok, profile} = profile |> Ecto.Changeset.change(avatar_path: path) |> Repo.update()
        if old, do: Avatar.delete(old)
        {:ok, profile}

      {:error, _reason} ->
        changeset =
          profile
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.add_error(:avatar_path, "couldn't read that image — try a JPG or PNG")

        {:error, %{changeset | action: :update}}
    end
  end

  defp attach_avatar(error, _source), do: error
end

defmodule PevSquad.Riders.NotAuthorizedError do
  defexception message: "only moderators and admins can manage rider profiles", plug_status: 403
end
