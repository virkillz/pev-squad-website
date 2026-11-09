defmodule PevSquadWeb.API.MeController do
  use PevSquadWeb, :api_controller

  alias PevSquad.{Accounts, Riders}
  alias PevSquadWeb.API.Schemas
  alias PevSquadWeb.API.Urls

  tags(["Me"])
  security([%{"bearer" => []}])

  operation(:update,
    summary: "Save the member's email language",
    request_body:
      {"Language", "application/json",
       PevSquadWeb.API.AuthSchemas.input([:locale], %{
         locale: %OpenApiSpex.Schema{type: :string, enum: ~w(id en)}
       }), required: true},
    responses: [ok: {"The user", "application/json", Schemas.Me}]
  )

  def update(conn, params) do
    with locale when locale in ["id", "en"] <- params["locale"],
         {:ok, user} <- Accounts.update_user_locale(conn.assigns.current_scope.user, locale) do
      conn |> assign(:current_scope, Accounts.Scope.for_user(user)) |> show(%{})
    else
      _ -> {:error, {:validation_failed, %{locale: ["must be id or en"]}}}
    end
  end

  operation(:profile,
    summary: "Create or edit your rider profile; new members await staff approval",
    request_body:
      {"Profile", "application/json", PevSquadWeb.API.AuthSchemas.profile(), required: true},
    responses: [ok: {"The user", "application/json", Schemas.Me}]
  )

  def profile(conn, params) do
    review_url = fn profile -> url(~p"/admin/riders/#{profile.id}/edit") end

    case Riders.save_my_profile(conn.assigns.current_scope, params, nil, review_url: review_url) do
      {:ok, _profile} -> show(conn, %{})
      {:error, :banned} -> {:error, :forbidden}
      error -> error
    end
  end

  operation(:avatar,
    summary: "Upload your rider photo",
    description:
      "Multipart form with a `file` field (JPEG, PNG or WebP, up to 10 MB). Cropped to 4:5 (800×1000) WebP with metadata, including GPS, stripped. Needs a rider profile first.",
    request_body: {"Image", "multipart/form-data", Schemas.FileUpload, required: true},
    responses: [
      ok: {"The user", "application/json", Schemas.Me},
      unprocessable_entity:
        {"Not an image, too big, or no profile yet", "application/json", Schemas.Error}
    ]
  )

  def avatar(conn, params) do
    scope = conn.assigns.current_scope

    with {:ok, upload} <- PevSquadWeb.API.Admin.UploadController.image_upload(params),
         :ok <- small_enough(upload),
         %{} <-
           Riders.get_my_profile(scope) ||
             {:error,
              {:validation_failed, %{file: [gettext("Create your rider profile first.")]}}},
         {:ok, _profile} <- Riders.save_my_profile(scope, %{}, upload.path) do
      show(conn, %{})
    else
      {:error, :banned} ->
        {:error, :forbidden}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, {:validation_failed, %{file: avatar_errors(changeset)}}}

      error ->
        error
    end
  end

  defp small_enough(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= 10_000_000 -> :ok
      _ -> {:error, {:validation_failed, %{file: [gettext("The photo is bigger than 10 MB.")]}}}
    end
  end

  defp avatar_errors(changeset) do
    changeset |> PevSquadWeb.API.Errors.changeset_fields() |> Map.values() |> List.flatten()
  end

  operation(:deletion,
    summary: "What deleting your account would remove, for the confirmation screen",
    responses: [ok: {"Footprint", "application/json", Schemas.Deletion}]
  )

  def deletion(conn, _params) do
    f = Accounts.own_footprint(conn.assigns.current_scope)

    json(conn, %{
      data: %{
        profile_alias: f.profile && f.profile.alias,
        reviews: f.reviews,
        photos: f.photos,
        listings: f.listings,
        hosted_rides: f.hosted_rides,
        upcoming_rsvps: f.upcoming_rsvps
      }
    })
  end

  operation(:delete,
    summary:
      "Permanently delete your account and what you posted. Needs a login in the last 20 minutes",
    responses: [
      no_content: "Deleted",
      forbidden:
        {"reauth_required: log in again first; forbidden: admins can't", "application/json",
         Schemas.Error}
    ]
  )

  def delete(conn, _params) do
    case Accounts.delete_own_account(
           conn.assigns.current_scope,
           &url(~p"/events/#{&1.slug}"),
           url(~p"/events")
         ) do
      {:ok, _user} -> send_resp(conn, :no_content, "")
      {:error, :admin} -> {:error, :forbidden}
      {:error, :reauth_required} -> {:error, :reauth_required}
    end
  end

  operation(:show,
    summary: "The signed-in user",
    responses: [
      ok: {"The user", "application/json", Schemas.Me},
      unauthorized: {"Missing or invalid token", "application/json", Schemas.Error}
    ]
  )

  def show(conn, _params) do
    scope = conn.assigns.current_scope
    user = scope.user
    profile = Riders.get_my_profile(scope)

    json(conn, %{
      data: %{
        id: user.id,
        email: user.email,
        role: user.role,
        locale: user.locale,
        rider_profile:
          profile &&
            %{
              alias: profile.alias,
              slug: profile.slug,
              status: profile.status,
              city: profile.city,
              main_ride: profile.main_ride,
              primary_pev_type: profile.primary_pev_type,
              bio: profile.bio,
              instagram: profile.instagram,
              is_public: profile.is_public,
              avatar_url: Urls.absolute(profile.avatar_path)
            }
      }
    })
  end
end
