defmodule PevSquadWeb.Layouts do
  @moduledoc """
  Site chrome shared by every page: masthead, hazard strip, footer and flashes.

  This replaces the nav/footer blocks that the static prototype duplicated
  across every HTML file.
  """
  use PevSquadWeb, :html

  embed_templates "layouts/*"

  # A function, not a module attribute, so the labels are translated at
  # render time in the rider's locale.
  defp nav do
    [
      {:home, "01", gettext("Home"), "/"},
      {:community, "02", gettext("Community"), "/community"},
      {:gallery, "03", gettext("Gallery"), "/gallery"},
      {:reviews, "04", gettext("Reviews"), "/reviews"},
      {:for_sale, "05", gettext("For Sale"), "/for-sale"},
      {:events, "06", gettext("Events"), "/events"},
      {:about, "07", gettext("About"), "/about"}
    ]
  end

  def default_description do
    gettext(
      "PEV Squad — speed, adventure, freedom. Indonesia's personal electric vehicle community: racing, touring and commuting on EUCs, scooters and boards."
    )
  end

  def og_locale do
    case PevSquadWeb.Locale.current() do
      "en" -> "en_US"
      _ -> "id_ID"
    end
  end

  def og_title(nil), do: "PEV Squad"
  def og_title(title), do: "#{title} — PEV Squad"

  @doc """
  Renders the site layout.

      <Layouts.app flash={@flash} current_scope={@current_scope} active={:events}>
        <section class="band band-black">...</section>
      </Layouts.app>

  Pages render their own `.band` sections; the layout adds no padding.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :active, :atom, default: nil, doc: "which nav item to highlight"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :nav, nav())

    ~H"""
    <header class="masthead">
      <.link class="brand" navigate={~p"/"}>
        <img src={~p"/images/logo.jpg"} alt="" class="brand-logo" />
        <span>
          <span class="brand-name">PEV Squad</span>
          <span class="brand-tag">/// EUC · SCOOTER · ESK8</span>
        </span>
      </.link>
      <nav class="mainnav" id="mainnav">
        <.link
          :for={{key, num, label, path} <- @nav}
          navigate={path}
          class={@active == key && "active"}
        >
          <span class="nav-num">{num}</span>{label}
        </.link>
        <%= if @current_scope do %>
          <.link
            :if={PevSquad.Accounts.Scope.staff?(@current_scope)}
            navigate={~p"/admin"}
            class={["nav-account", @active == :admin && "active"]}
          >
            {gettext("Admin")}
          </.link>
          <.link
            navigate={~p"/users/profile"}
            class={["nav-account", @active == :account && "active"]}
          >
            {gettext("Account")}
          </.link>
          <.link href={~p"/users/log-out"} method="delete">{gettext("Log out")}</.link>
        <% else %>
          <.link navigate={~p"/users/log-in"} class={["nav-account", @active == :account && "active"]}>
            {gettext("Log in")}
          </.link>
        <% end %>
        <.language_switch />
      </nav>
      <button class="nav-toggle" type="button" aria-controls="mainnav" aria-expanded="false">
        {gettext("Menu")}
      </button>
    </header>

    <div class="hazard"></div>

    <main>
      {render_slot(@inner_block)}
    </main>

    <.site_footer />
    <.flash_group flash={@flash} />
    """
  end

  def site_footer(assigns) do
    ~H"""
    <footer class="site-footer">
      <div class="footer-grid">
        <div>
          <h2 class="footer-big">WE TAKE IT<br /><em>PERSONAL.</em></h2>
          <div style="margin-top:3rem;">
            <span class="eyebrow">{gettext("Basecamp")}</span>
            <p style="margin-top:0.5rem; line-height:1.5;">
              JAKARTA · BANDUNG · SURABAYA<br />SEMARANG · YOGYAKARTA · BEKASI
            </p>
          </div>
        </div>
        <div class="footer-col">
          <h4>{gettext("Explore")}</h4>
          <ul>
            <li><.link navigate={~p"/community"}>{gettext("Community")}</.link></li>
            <li><.link navigate={~p"/gallery"}>{gettext("Gallery")}</.link></li>
            <li><.link navigate={~p"/reviews"}>{gettext("Reviews")}</.link></li>
            <li><.link navigate={~p"/for-sale"}>{gettext("For Sale")}</.link></li>
            <li><.link navigate={~p"/events"}>{gettext("Events")}</.link></li>
            <li><.link navigate={~p"/about"}>{gettext("About")}</.link></li>
          </ul>
        </div>
        <div class="footer-col">
          <h4>{gettext("Follow")}</h4>
          <ul>
            <li><a href="#">Instagram</a></li>
            <li><a href="#">WhatsApp</a></li>
            <li><a href="#">YouTube</a></li>
          </ul>
        </div>
      </div>
      <div class="footer-bottom">
        <span>© {Date.utc_today().year} PEV SQUAD</span>
        <span>EUC / ESCOOTER / ESK8 — INDONESIA</span>
      </div>
    </footer>
    """
  end

  @doc """
  EN / ID toggle. A plain link (full page load) so the plug stores the
  choice in the session and every LiveView remounts in the new language.
  """
  def language_switch(assigns) do
    assigns = assign(assigns, :current, PevSquadWeb.Locale.current())

    ~H"""
    <span class="lang-switch" aria-label={gettext("Language")}>
      <a
        :for={{code, label} <- [{"id", "ID"}, {"en", "EN"}]}
        href={~p"/locale/#{code}"}
        lang={code}
        hreflang={code}
        class={@current == code && "active"}
        aria-current={@current == code && "true"}
      >
        {label}
      </a>
    </span>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
