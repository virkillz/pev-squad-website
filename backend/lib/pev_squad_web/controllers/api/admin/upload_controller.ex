defmodule PevSquadWeb.API.Admin.UploadController do
  use PevSquadWeb, :api_controller

  alias PevSquad.Posts
  alias PevSquadWeb.API.Schemas
  alias PevSquadWeb.API.Urls

  tags(["Admin: uploads"])
  security([%{"bearer" => []}])

  @types ~w(image/jpeg image/png image/webp)

  operation(:create,
    summary: "Upload an image for a post body",
    description:
      "Multipart form with a `file` field (JPEG, PNG or WebP, up to 15 MB). Stored as 1600px WebP with metadata stripped. Put `markdown` into the post body.",
    request_body: {"Image", "multipart/form-data", Schemas.FileUpload, required: true},
    responses: [
      created: {"Stored", "application/json", Schemas.Upload},
      unprocessable_entity: {"Not an image", "application/json", Schemas.Error}
    ]
  )

  def create(conn, params) do
    with {:ok, upload} <- image_upload(params) do
      case Posts.store_inline_image(conn.assigns.current_scope, upload.path) do
        {:ok, path} ->
          conn
          |> put_status(:created)
          |> json(%{data: %{path: path, url: Urls.absolute(path), markdown: "![](#{path})"}})

        {:error, :bad_image} ->
          {:error, bad_image()}
      end
    end
  end

  @doc false
  def image_upload(%{"file" => %Plug.Upload{content_type: type} = upload}) when type in @types,
    do: {:ok, upload}

  def image_upload(_params), do: {:error, bad_image()}

  @doc false
  def bad_image,
    do: {:validation_failed, %{"file" => [gettext("send a JPEG, PNG or WebP image as `file`")]}}
end
