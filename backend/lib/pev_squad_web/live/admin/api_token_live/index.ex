defmodule PevSquadWeb.Admin.ApiTokenLive.Index do
  @moduledoc """
  Personal API tokens for staff tools such as the `pev` CLI (DESIGN.md §7.2).

  Staff only see and revoke their own tokens. Creating one needs a recent
  login (sudo mode), and the token is shown once, right after creation.
  """
  use PevSquadWeb, :live_view

  alias PevSquad.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active={:admin}>
      <section class="band band-white">
        <div class="section-head">
          <div>
            <span class="eyebrow">Admin</span>
            <h1 class="section-title">API Tokens</h1>
            <p class="section-lede">
              Personal tokens for the <code>pev</code>
              command-line tool and AI assistants that draft events, news and articles from your computer. A token acts as you, so keep it out of git and revoke it if a laptop is lost. Tokens expire after a year.
            </p>
          </div>
        </div>

        <div :if={@new_token} id="new-token" class="notice" style="margin-bottom:2rem;">
          <p><strong>Copy this token now. It won't be shown again.</strong></p>
          <pre id="new-token-value" style="margin:1rem 0;white-space:pre-wrap;word-break:break-all;"><code>{@new_token}</code></pre>
          <p class="section-lede">
            Use it as <code>export PEV_API_TOKEN=…</code>
            in your shell profile, or send it as <code>Authorization: Bearer …</code>.
          </p>
          <.button type="button" phx-click="dismiss" class="btn btn-outline">Done</.button>
        </div>

        <.form
          for={@form}
          id="token-form"
          phx-submit="create"
          class="notice"
          style="margin-bottom:2rem;"
        >
          <div class="grid grid-cols-1 sm:grid-cols-4 gap-4 items-end">
            <div class="sm:col-span-3">
              <.input
                field={@form[:name]}
                type="text"
                label="Name"
                placeholder="e.g. MacBook CLI"
                maxlength="60"
              />
            </div>
            <div class="fieldset mb-2">
              <.button variant="primary" class="btn btn-primary w-full">Create token</.button>
            </div>
          </div>
        </.form>

        <.table id="api-tokens" rows={@tokens}>
          <:col :let={t} label="Name">{t.name}</:col>
          <:col :let={t} label="Created">{format_dt(t.inserted_at)}</:col>
          <:col :let={t} label="Last used">{format_dt(t.last_used_at) || "Never"}</:col>
          <:col :let={t} label="Expires">{format_dt(t.expires_at)}</:col>
          <:action :let={t}>
            <.link
              phx-click="revoke"
              phx-value-id={t.id}
              data-confirm={"Revoke \"#{t.name}\"? Anything using it stops working."}
              class="link-orange"
            >
              Revoke
            </.link>
          </:action>
        </.table>
        <p :if={@tokens == []} class="section-lede">No tokens yet.</p>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin · API Tokens")
     |> assign(:new_token, nil)
     |> assign(:form, to_form(Accounts.change_api_token(), as: :token))
     |> load_tokens()}
  end

  @impl true
  def handle_event("create", %{"token" => params}, socket) do
    scope = socket.assigns.current_scope

    if Accounts.sudo_mode?(scope.user) do
      case Accounts.create_api_token(scope, params) do
        {:ok, plaintext, _token} ->
          {:noreply,
           socket
           |> assign(:new_token, plaintext)
           |> assign(:form, to_form(Accounts.change_api_token(), as: :token))
           |> load_tokens()}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset, as: :token, action: :insert))}

        {:error, :forbidden} ->
          {:noreply, put_flash(socket, :error, "Only staff can create API tokens.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Log in again to create an API token.")
       |> redirect(to: ~p"/users/log-in")}
    end
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    case Accounts.delete_api_token(socket.assigns.current_scope, id) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "Token revoked.") |> load_tokens()}
      {:error, :not_found} -> {:noreply, load_tokens(socket)}
    end
  end

  def handle_event("dismiss", _params, socket), do: {:noreply, assign(socket, :new_token, nil)}

  defp load_tokens(socket) do
    assign(socket, :tokens, Accounts.list_api_tokens(socket.assigns.current_scope))
  end

  defp format_dt(nil), do: nil
  defp format_dt(dt), do: Calendar.strftime(dt, "%d %b %Y")
end
