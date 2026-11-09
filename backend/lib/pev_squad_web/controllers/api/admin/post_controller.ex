defmodule PevSquadWeb.API.Admin.PostController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Posts
  alias PevSquadWeb.API.{AdminParams, Errors}
  alias PevSquadWeb.API.Schemas

  tags(["Admin: posts"])
  security([%{"bearer" => []}])

  @id_param [id: [in: :path, type: :string, description: "Post id or slug", required: true]]

  operation(:index,
    summary: "List news and articles (all statuses)",
    parameters: [
      kind: [in: :query, type: :string, description: "news | article"],
      status: [in: :query, type: :string, description: "draft | published"]
    ],
    responses: [ok: {"Posts", "application/json", Schemas.PostList}]
  )

  def index(conn, params) do
    with {:ok, kind} <- enum_param(params, "kind", Posts.Post.kinds()),
         {:ok, status} <- enum_param(params, "status", Posts.Post.statuses()) do
      posts = Posts.list_posts_for_staff(conn.assigns.current_scope, kind: kind, status: status)
      render(conn, :index, posts: posts)
    end
  end

  operation(:show,
    summary: "One post with all its text",
    parameters: @id_param,
    responses: [
      ok: {"Post", "application/json", Schemas.Post},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    with {:ok, post} <- Posts.fetch_post(conn.assigns.current_scope, id) do
      render(conn, :show, post: post)
    end
  end

  operation(:create,
    summary: "Create a draft post",
    description:
      "Always a draft; publish it in /admin. Translations default to machine_translated: true.",
    request_body: {"Post", "application/json", Schemas.PostInput, required: true},
    responses: [
      created: {"Created", "application/json", Schemas.Post},
      unprocessable_entity: {"Invalid", "application/json", Schemas.Error}
    ]
  )

  def create(conn, params) do
    scope = conn.assigns.current_scope

    with :ok <- AdminParams.refuse_publishing(params),
         {:ok, attrs} <- AdminParams.post_attrs(params),
         {:ok, post} <- Posts.create_post(scope, attrs) do
      conn |> put_status(:created) |> render(:show, post: post)
    end
  end

  operation(:update,
    summary: "Change a draft post",
    description:
      "Only the fields you send change. In translations, send only the languages to change; null deletes one.",
    parameters: @id_param,
    request_body: {"Post", "application/json", Schemas.PostInput, required: true},
    responses: [
      ok: {"Post", "application/json", Schemas.Post},
      conflict: {"Already published", "application/json", Schemas.Error},
      unprocessable_entity: {"Invalid", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, post} <- Posts.fetch_post(scope, id),
         :ok <- AdminParams.editable?(post),
         :ok <- AdminParams.refuse_publishing(params),
         {:ok, attrs} <- AdminParams.post_attrs(Map.delete(params, "id"), post),
         {:ok, post} <- Posts.update_post(scope, post, attrs) do
      render(conn, :show, post: post)
    end
  end

  operation(:cover,
    summary: "Set a draft post's cover image",
    description: "Multipart form with a `file` field (JPEG, PNG or WebP, up to 15 MB).",
    parameters: @id_param,
    request_body: {"Image", "multipart/form-data", Schemas.FileUpload, required: true},
    responses: [
      ok: {"Post", "application/json", Schemas.Post},
      conflict: {"Already published", "application/json", Schemas.Error},
      unprocessable_entity: {"Not an image", "application/json", Schemas.Error}
    ]
  )

  def cover(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope

    with {:ok, post} <- Posts.fetch_post(scope, id),
         :ok <- AdminParams.editable?(post),
         {:ok, upload} <- PevSquadWeb.API.Admin.UploadController.image_upload(params) do
      case Posts.update_post(scope, post, %{}, upload.path) do
        {:ok, post} -> render(conn, :show, post: post)
        {:error, :bad_image} -> {:error, PevSquadWeb.API.Admin.UploadController.bad_image()}
        error -> error
      end
    end
  end

  defp enum_param(params, key, allowed) do
    case params[key] do
      nil ->
        {:ok, nil}

      value ->
        case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
          nil ->
            {:error, {:validation_failed, %{key => [Errors.message(:validation_failed)]}}}

          atom ->
            {:ok, atom}
        end
    end
  end
end
