defmodule PevSquadWeb.API.Admin.EventController do
  use PevSquadWeb, :api_controller

  alias PevSquad.{Events, Partners}
  alias PevSquadWeb.API.AdminParams
  alias PevSquadWeb.API.Schemas

  tags(["Admin: events"])
  security([%{"bearer" => []}])

  @id_param [id: [in: :path, type: :string, description: "Event id or slug", required: true]]

  operation(:index,
    summary: "List events (all statuses and categories)",
    parameters: [
      status: [in: :query, type: :string, description: "draft | published | cancelled | hidden"],
      category: [in: :query, type: :string, description: "official | group_ride"],
      upcoming: [in: :query, type: :boolean, description: "Only events that haven't started"]
    ],
    responses: [ok: {"Events", "application/json", Schemas.EventList}]
  )

  def index(conn, params) do
    opts = [
      status: enum(params["status"], Events.Event.statuses()),
      category: enum(params["category"], Events.Event.categories()),
      upcoming: params["upcoming"] in ["true", "1"]
    ]

    render(conn, :index, events: Events.list_events_for_staff(conn.assigns.current_scope, opts))
  end

  operation(:show,
    summary: "One event",
    parameters: @id_param,
    responses: [
      ok: {"Event", "application/json", Schemas.Event},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    with {:ok, event} <- Events.fetch_event(conn.assigns.current_scope, id) do
      render_event(conn, event)
    end
  end

  operation(:create,
    summary: "Create a draft official event",
    description:
      "Always a draft; publish it in /admin. Times may include an offset, or be local to `timezone` (default Asia/Jakarta).",
    request_body: {"Event", "application/json", Schemas.EventInput, required: true},
    responses: [
      created: {"Created", "application/json", Schemas.Event},
      unprocessable_entity: {"Invalid", "application/json", Schemas.Error}
    ]
  )

  def create(conn, params) do
    scope = conn.assigns.current_scope

    with :ok <- AdminParams.refuse_publishing(params),
         {:ok, partner_ids} <- AdminParams.partner_ids(params),
         {:ok, event} <- Events.create_event(scope, AdminParams.event_attrs(params)) do
      if partner_ids, do: {:ok, _} = Partners.set_event_partners(scope, event, partner_ids)
      {:ok, event} = Events.fetch_event(scope, event.id)
      conn |> put_status(:created) |> render_event(event)
    end
  end

  operation(:update,
    summary: "Change a draft official event",
    description: "Only the fields you send change. `partner_ids` replaces the linked partners.",
    parameters: @id_param,
    request_body: {"Event", "application/json", Schemas.EventInput, required: true},
    responses: [
      ok: {"Event", "application/json", Schemas.Event},
      conflict: {"Published, or a group ride", "application/json", Schemas.Error},
      unprocessable_entity: {"Invalid", "application/json", Schemas.Error}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    params = Map.delete(params, "id")

    with {:ok, event} <- Events.fetch_event(scope, id),
         :ok <- AdminParams.editable?(event),
         :ok <- AdminParams.refuse_publishing(params),
         {:ok, partner_ids} <- AdminParams.partner_ids(params),
         {:ok, _} <-
           Events.update_event(scope, event, AdminParams.event_attrs(params, event), &event_url/1) do
      if partner_ids, do: {:ok, _} = Partners.set_event_partners(scope, event, partner_ids)
      {:ok, event} = Events.fetch_event(scope, event.id)
      render_event(conn, event)
    end
  end

  defp render_event(conn, event) do
    partner_ids = event |> Partners.list_event_partners(all: true) |> Enum.map(& &1.id)
    render(conn, :show, event: event, partner_ids: partner_ids)
  end

  defp event_url(event), do: url(~p"/events/#{event.slug}")

  defp enum(nil, _allowed), do: nil
  defp enum(value, allowed), do: Enum.find(allowed, &(Atom.to_string(&1) == value))
end
