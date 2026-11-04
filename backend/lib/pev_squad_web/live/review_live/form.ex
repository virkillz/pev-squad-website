defmodule PevSquadWeb.ReviewLive.Form do
  use PevSquadWeb, :live_view

  alias PevSquad.{Reviews, Riders}
  alias PevSquad.Reviews.{PevModel, Review}

  import PevSquadWeb.RiderComponents, only: [type_options: 0]

  @new_model "__new__"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:reviews}>
      <section class="band band-black">
        <div class="panel panel-wide space-y-4">
          <.header>
            {@page_title}
            <:subtitle>
              Ridden, not sponsored: review gear you own. Your review appears under your alias <strong>{@profile.alias}</strong>.
              <span :if={!@trusted?}>
                A moderator checks new members' reviews before they go live.
              </span>
            </:subtitle>
          </.header>

          <p :if={@review.status == :rejected} class="notice">
            <strong>Moderator's note:</strong> {@review.rejection_reason}
          </p>

          <.form
            for={@form}
            id="review-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
          >
            <.input
              field={@form[:pev_model_id]}
              type="select"
              label="Model"
              prompt="Pick the model you ride"
              options={@model_options}
              disabled={@live_action == :edit}
            />

            <div :if={@adding_model?} class="notice space-y-2" id="new-model">
              <p>Add it to the catalog — a moderator will check it.</p>
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <.input
                  field={@model_form[:pev_type]}
                  type="select"
                  label="Type"
                  options={type_options()}
                />
                <.input field={@model_form[:brand]} type="text" label="Brand" placeholder="Begode" />
                <.input field={@model_form[:name]} type="text" label="Model" placeholder="Master Pro" />
              </div>
            </div>

            <.input
              field={@form[:headline]}
              type="text"
              label="Headline — your verdict in a few words"
              placeholder="Most planted wheel"
            />
            <.input
              field={@form[:summary]}
              type="textarea"
              label="Summary (max 280 characters, shown on the card)"
            />
            <.input
              field={@form[:the_ride]}
              type="textarea"
              label="The Ride — what it's like to live with"
            />
            <.input
              field={@form[:the_catch]}
              type="textarea"
              label="The Catch — what you'd warn a friend about (optional)"
            />
            <.input field={@form[:km_on_unit]} type="number" min="0" label="Km on your unit" />

            <div class="fieldset">
              <span class="label mb-1">Scores, 0–10 (one decimal)</span>
              <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
                <.input
                  :for={{key, label} <- Review.criteria()}
                  field={@form[Review.score_field(key)]}
                  type="number"
                  step="0.1"
                  min="0"
                  max="10"
                  label={if key == :app, do: "#{label} (optional)", else: label}
                />
              </div>
            </div>

            <div class="flex gap-3 pt-4">
              <.button phx-disable-with="Saving..." variant="primary">
                {if @trusted?, do: "Publish review", else: "Submit for review"}
              </.button>
              <.button navigate={if @review.id, do: ~p"/reviews/#{@review.id}", else: ~p"/reviews"}>
                Cancel
              </.button>
            </div>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    scope = socket.assigns.current_scope

    case Riders.get_my_profile(scope) do
      nil ->
        {:ok,
         socket
         |> put_flash(
           :error,
           "Set up your rider profile first — reviews are shown under your alias."
         )
         |> push_navigate(to: ~p"/users/profile")}

      profile ->
        {:ok,
         socket
         |> assign(:profile, profile)
         |> assign(:trusted?, Reviews.trusted?(scope))
         |> assign(:model_form, to_form(Reviews.change_model(%PevModel{}), as: :new_model))
         |> apply_action(socket.assigns.live_action, params)}
    end
  end

  defp apply_action(socket, :new, params) do
    scope = socket.assigns.current_scope
    models = Reviews.list_selectable_models(scope)
    preselected = Enum.find(models, &(&1.slug == params["model"]))
    review = %Review{pev_model_id: preselected && preselected.id}

    socket
    |> assign(:page_title, "Write a review")
    |> assign(:review, review)
    |> assign(:model_options, model_options(models, true))
    |> assign(:adding_model?, false)
    |> assign(:form, to_form(Reviews.change_review(review)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    scope = socket.assigns.current_scope
    review = Reviews.get_my_review!(scope, id)

    socket
    |> assign(:page_title, "Edit review")
    |> assign(:review, review)
    |> assign(:model_options, model_options(Reviews.list_selectable_models(scope), false))
    |> assign(:adding_model?, false)
    |> assign(:form, to_form(Reviews.change_review(review)))
  end

  defp model_options(models, allow_new?) do
    options =
      Enum.map(models, fn m ->
        {PevModel.full_name(m) <> if(m.approved, do: "", else: " (pending)"), m.id}
      end)

    if allow_new?, do: options ++ [{"Not listed — add it…", @new_model}], else: options
  end

  @impl true
  def handle_event("validate", %{"review" => params} = all, socket) do
    adding? = params["pev_model_id"] == @new_model
    changeset = Reviews.change_review(socket.assigns.review, review_params(params))

    model_form =
      if adding?,
        do:
          to_form(Reviews.change_model(%PevModel{}, all["new_model"] || %{}),
            as: :new_model,
            action: :validate
          ),
        else: socket.assigns.model_form

    {:noreply,
     socket
     |> assign(:adding_model?, adding?)
     |> assign(:model_form, model_form)
     |> assign(:form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"review" => params} = all, socket) do
    scope = socket.assigns.current_scope

    result =
      case socket.assigns.live_action do
        :new ->
          new_model = if params["pev_model_id"] == @new_model, do: all["new_model"] || %{}
          Reviews.create_review(scope, review_params(params), new_model)

        :edit ->
          Reviews.update_review(scope, socket.assigns.review, review_params(params))
      end

    case result do
      {:ok, review} ->
        message =
          if review.status == :published,
            do: "Review published.",
            else: "Thanks! A moderator will check it shortly."

        {:noreply,
         socket |> put_flash(:info, message) |> push_navigate(to: ~p"/reviews/#{review.id}")}

      {:error, :no_profile} ->
        {:noreply, push_navigate(socket, to: ~p"/users/profile")}

      {:error, %Ecto.Changeset{data: %PevModel{}} = changeset} ->
        {:noreply, assign(socket, :model_form, to_form(changeset, as: :new_model))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp review_params(%{"pev_model_id" => @new_model} = params),
    do: Map.delete(params, "pev_model_id")

  defp review_params(params), do: params
end
