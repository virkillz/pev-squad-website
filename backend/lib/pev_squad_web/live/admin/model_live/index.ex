defmodule PevSquadWeb.Admin.ModelLive.Index do
  use PevSquadWeb, :live_view

  alias PevSquad.Reviews
  alias PevSquad.Reviews.PevModel

  import PevSquadWeb.RiderComponents, only: [type_label: 1, type_options: 0]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:reviews}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin</span>
            <h1 class="section-title">Model Catalog</h1>
            <p class="section-lede">
              Models riders can review. Members' suggestions stay pending until you approve their review or the model here.
            </p>
          </div>
          <.link navigate={~p"/admin/reviews"} class="btn btn-outline">Review queue</.link>
        </div>

        <.form
          for={@form}
          id="model-form"
          phx-change="validate"
          phx-submit="save"
          class="notice"
          style="margin-bottom:2rem;"
        >
          <div class="grid grid-cols-1 sm:grid-cols-4 gap-4 items-end">
            <.input field={@form[:pev_type]} type="select" label="Type" options={type_options()} />
            <.input field={@form[:brand]} type="text" label="Brand" />
            <.input field={@form[:name]} type="text" label="Model" />
            <div class="fieldset mb-2">
              <.button variant="primary" class="btn btn-primary w-full">
                {if @editing, do: "Save", else: "Add model"}
              </.button>
            </div>
          </div>
          <.input
            :if={@editing}
            field={@form[:approved]}
            type="checkbox"
            label="Approved (listed publicly)"
          />
          <.button :if={@editing} type="button" phx-click="cancel_edit" class="btn btn-ghost">
            Cancel editing
          </.button>
        </.form>

        <.table id="models" rows={@models}>
          <:col :let={model} label="Model">{PevModel.full_name(model)}</:col>
          <:col :let={model} label="Type">{type_label(model.pev_type)}</:col>
          <:col :let={model} label="Status">
            {if model.approved, do: "Approved", else: "Pending"}
          </:col>
          <:action :let={model}>
            <.link phx-click="edit" phx-value-id={model.id} class="link-orange">Edit</.link>
          </:action>
          <:action :let={model}>
            <.link
              :if={!model.approved}
              phx-click="approve"
              phx-value-id={model.id}
              class="link-orange"
            >
              Approve
            </.link>
          </:action>
        </.table>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Admin · Models") |> reset_form() |> load()}
  end

  defp load(socket),
    do: assign(socket, :models, Reviews.list_models_for_staff(socket.assigns.current_scope))

  defp reset_form(socket) do
    socket
    |> assign(:editing, nil)
    |> assign(:form, to_form(Reviews.change_model_for_staff(%PevModel{})))
  end

  @impl true
  def handle_event("validate", %{"pev_model" => params}, socket) do
    model = socket.assigns.editing || %PevModel{}
    changeset = Reviews.change_model_for_staff(model, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"pev_model" => params}, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.editing do
        nil -> Reviews.create_model(scope, params)
        model -> Reviews.update_model(scope, model, params)
      end

    case result do
      {:ok, model} ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved #{PevModel.full_name(model)}.")
         |> reset_form()
         |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    model = Reviews.get_model_for_staff!(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> assign(:editing, model)
     |> assign(:form, to_form(Reviews.change_model_for_staff(model)))}
  end

  def handle_event("cancel_edit", _params, socket), do: {:noreply, reset_form(socket)}

  def handle_event("approve", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    model = Reviews.get_model_for_staff!(scope, id)
    {:ok, _} = Reviews.update_model(scope, model, %{approved: true})
    {:noreply, load(socket)}
  end
end
