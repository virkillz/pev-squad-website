defmodule PevSquadWeb.API.SafetyController do
  @moduledoc """
  Report and block (App Store 1.2, Google Play UGC policy). Targets are a
  rider profile, a gallery photo, a group ride or a review, addressed by
  `target_type` + `target_id`; the server works out who owns them, so the
  API never hands out user ids except for members you blocked.
  """
  use PevSquadWeb, :api_controller

  alias OpenApiSpex.Schema
  alias PevSquad.Safety
  alias PevSquad.Safety.Report
  alias PevSquadWeb.API.Schemas
  import PevSquadWeb.API.Schemas.Safety

  tags(["Safety"])
  security([%{"bearer" => []}])

  @types ~w(profile photo event review)

  operation(:reasons,
    summary: "Report reasons, labelled in the request language",
    responses: [
      ok:
        {"Reasons", "application/json",
         obj(%{data: list(obj(%{value: enum(Report.reason_values()), label: str()}))})}
    ]
  )

  def reasons(conn, _params) do
    json(conn, %{
      data: Enum.map(Report.reasons(), fn {value, label} -> %{value: value, label: label} end)
    })
  end

  operation(:report,
    summary: "Report something; optionally block its owner in the same step",
    request_body:
      {"Report", "application/json",
       obj(
         Map.merge(target_props(), %{
           reason: enum(Report.reason_values()),
           notes: %Schema{type: :string, nullable: true, maxLength: 1000},
           block: %Schema{type: :boolean, description: "Also block the owner"}
         }),
         [:target_type, :target_id, :reason]
       ), required: true},
    responses: [
      created: {"Reported", "application/json", obj(%{data: obj(%{blocked: bool()})})},
      not_found: {"Not found", "application/json", Schemas.Error},
      unprocessable_entity:
        {"Invalid, already reported, or your own", "application/json", Schemas.Error}
    ]
  )

  def report(conn, params) do
    scope = conn.assigns.current_scope

    with {:ok, type, id} <- target(params),
         {:ok, target} <- Safety.get_target(type, id),
         {:ok, _report} <-
           own_content(Safety.report(scope, type, id, Map.take(params, ["reason", "notes"]))) do
      owner = Safety.target_user_id(target)

      blocked? =
        params["block"] == true and owner != nil and match?({:ok, _}, Safety.block(scope, owner))

      conn |> put_status(:created) |> json(%{data: %{blocked: blocked?}})
    end
  end

  operation(:blocks,
    summary: "Members you blocked",
    responses: [ok: {"Blocked", "application/json", obj(%{data: list(blocked_member())})}]
  )

  def blocks(conn, _params) do
    json(conn, %{data: Safety.list_blocked(conn.assigns.current_scope)})
  end

  operation(:block,
    summary: "Block the owner of a profile, photo, group ride or review",
    request_body: {"Target", "application/json", obj(target_props()), required: true},
    responses: [
      created: {"Blocked", "application/json", obj(%{data: blocked_member()})},
      unprocessable_entity: {"Your own, or nobody to block", "application/json", Schemas.Error}
    ]
  )

  def block(conn, params) do
    scope = conn.assigns.current_scope

    with {:ok, type, id} <- target(params),
         {:ok, target} <- Safety.get_target(type, id),
         {:ok, owner} <- owner(target),
         {:ok, _block} <- own_content(Safety.block(scope, owner)) do
      alias =
        Enum.find_value(Safety.list_blocked(scope), fn b -> b.user_id == owner && b.alias end)

      conn |> put_status(:created) |> json(%{data: %{user_id: owner, alias: alias || nil}})
    else
      {:error, :no_owner} ->
        invalid(
          gettext("This profile isn't linked to a member account, so there's nobody to block.")
        )

      other ->
        other
    end
  end

  operation(:unblock,
    summary: "Unblock a member (idempotent)",
    parameters: [user_id: [in: :path, type: :integer, required: true]],
    responses: [no_content: "Unblocked"]
  )

  def unblock(conn, %{"user_id" => user_id}) do
    case Integer.parse(user_id) do
      {id, ""} ->
        :ok = Safety.unblock(conn.assigns.current_scope, id)
        send_resp(conn, :no_content, "")

      _ ->
        {:error, :not_found}
    end
  end

  defp owner(target) do
    case Safety.target_user_id(target) do
      nil -> {:error, :no_owner}
      id -> {:ok, id}
    end
  end

  defp target(%{"target_type" => type, "target_id" => id}) when type in @types do
    case {Safety.parse_type(type), parse_id(id)} do
      {{:ok, type}, {:ok, id}} -> {:ok, type, id}
      _ -> {:error, :not_found}
    end
  end

  defp target(_params),
    do:
      {:error,
       {:validation_failed, %{target_type: [gettext("must be profile, photo, event or review")]}}}

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp parse_id(_id), do: :error

  defp own_content({:error, reason}) when reason in [:own_content, :self],
    do: invalid(gettext("That's yours."))

  defp own_content(result), do: result

  defp invalid(message), do: {:error, {:validation_failed, %{target_id: [message]}}}
end
