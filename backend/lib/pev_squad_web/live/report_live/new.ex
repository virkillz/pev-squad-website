defmodule PevSquadWeb.ReportLive.New do
  use PevSquadWeb, :live_view

  alias PevSquad.Gallery.Photo
  alias PevSquad.Reviews.{PevModel, Review}
  alias PevSquad.Riders.RiderProfile
  alias PevSquad.Safety
  alias PevSquad.Safety.Report

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="band band-black">
        <div class="panel space-y-4">
          <.header>
            Report
            <:subtitle>
              {describe(@target)}. Moderators see who reported; the rider doesn't.
            </:subtitle>
          </.header>

          <.form for={@form} id="report-form" phx-submit="save" class="space-y-3">
            <fieldset class="fieldset space-y-2">
              <span class="label">What's wrong?</span>
              <label
                :for={{value, label} <- Report.reasons()}
                class="flex gap-2 items-center cursor-pointer"
              >
                <input
                  type="radio"
                  name="report[reason]"
                  value={value}
                  checked={to_string(@form[:reason].value) == to_string(value)}
                  class="checkbox"
                />
                <span>{label}</span>
              </label>
              <p :for={{msg, _} <- Keyword.get_values(@form.errors, :reason)} class="text-error">
                {msg}
              </p>
            </fieldset>

            <.input
              field={@form[:notes]}
              type="textarea"
              label="Anything moderators should know? (optional)"
            />

            <label :if={@owner_id} class="flex gap-2 items-center cursor-pointer">
              <input type="checkbox" name="block" value="true" class="checkbox" />
              <span>Also block this rider — hide their profile, reviews and photos from me</span>
            </label>

            <div class="flex gap-3 pt-2">
              <.button variant="primary" phx-disable-with="Sending...">Send report</.button>
              <.button navigate={@return_to}>Cancel</.button>
            </div>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"type" => type, "id" => id}, _session, socket) do
    with {:ok, type} <- Safety.parse_type(type),
         {id, ""} <- Integer.parse(id),
         {:ok, target} <- Safety.get_target(type, id) do
      {:ok,
       socket
       |> assign(:page_title, "Report")
       |> assign(:type, type)
       |> assign(:target, target)
       |> assign(:owner_id, Safety.target_user_id(target))
       |> assign(:return_to, return_to(target))
       |> assign(:form, to_form(Safety.change_report()))}
    else
      _ -> raise Ecto.NoResultsError, queryable: Report
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    scope = socket.assigns.current_scope
    %{type: type, target: target, owner_id: owner_id} = socket.assigns

    case Safety.report(scope, type, target.id, params["report"] || %{}) do
      {:ok, _report} ->
        blocked? = params["block"] == "true" and owner_id != nil
        if blocked?, do: Safety.block(scope, owner_id)

        message =
          if blocked?,
            do: "Thanks — reported and blocked. You won't see their content any more.",
            else: "Thanks — the moderators will take a look."

        return_to =
          if blocked? and type == :profile, do: ~p"/community", else: socket.assigns.return_to

        {:noreply, socket |> put_flash(:info, message) |> push_navigate(to: return_to)}

      {:error, :own_content} ->
        {:noreply, put_flash(socket, :error, "That's your own — edit or delete it instead.")}

      {:error, :not_found} ->
        {:noreply,
         socket |> put_flash(:info, "That's already been taken down.") |> push_navigate(to: ~p"/")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp describe(%Review{} = r),
    do: "The #{PevModel.full_name(r.pev_model)} review “#{r.headline}”"

  defp describe(%Photo{} = p),
    do: "A photo#{if p.title, do: " (“#{p.title}”)"} in #{p.album.title}"

  defp describe(%RiderProfile{} = p), do: "#{p.alias}'s rider profile"

  defp return_to(%Review{id: id}), do: ~p"/reviews/#{id}"
  defp return_to(%Photo{album: album}), do: ~p"/gallery/#{album.slug}"
  defp return_to(%RiderProfile{slug: slug}), do: ~p"/community/#{slug}"
end
