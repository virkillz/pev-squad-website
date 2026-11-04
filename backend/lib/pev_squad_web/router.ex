defmodule PevSquadWeb.Router do
  use PevSquadWeb, :router

  import PevSquadWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PevSquadWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PevSquadWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [{PevSquadWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive.Index, :index
      live "/events", EventLive.Index, :index
      live "/events/:slug", EventLive.Show, :show
      live "/community", CommunityLive.Index, :index
      live "/community/:slug", CommunityLive.Show, :show
      live "/riders", RiderLive.Featured, :index
      live "/reviews", ReviewLive.Index, :index
      live "/gallery", GalleryLive.Index, :index
      live "/models/:slug", ModelLive.Show, :show
    end

    # Sections still living in the static prototype.
    get "/for-sale", PageController, :coming_soon
  end

  scope "/admin", PevSquadWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user]

    live_session :staff,
      on_mount: [{PevSquadWeb.UserAuth, :require_staff}] do
      live "/", Dashboard, :index
      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Form, :new
      live "/events/:id/edit", EventLive.Form, :edit
      live "/riders", RiderLive.Index, :index
      live "/riders/:id/edit", RiderLive.Edit, :edit
      live "/reviews", ReviewLive.Queue, :index
      live "/models", ModelLive.Index, :index
      live "/albums", AlbumLive.Index, :index
      live "/albums/new", AlbumLive.Form, :new
      live "/albums/:id/edit", AlbumLive.Form, :edit
      live "/photos", PhotoLive.Queue, :index
      live "/reports", ReportLive.Index, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", PevSquadWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pev_squad, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PevSquadWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PevSquadWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PevSquadWeb.UserAuth, :require_authenticated}, PevSquadWeb.AuthTitles] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/profile", UserLive.Profile, :edit
      live "/reviews/new", ReviewLive.Form, :new
      live "/group-rides/new", GroupRideLive.Form, :new
      live "/group-rides/:id/edit", GroupRideLive.Form, :edit
      live "/reviews/:id/edit", ReviewLive.Form, :edit
      live "/gallery/:slug/upload", GalleryLive.Upload, :new
      live "/report/:type/:id", ReportLive.New, :new
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  # After the authenticated routes so that /reviews/new isn't taken as an id.
  scope "/", PevSquadWeb do
    pipe_through :browser

    live_session :public_reviews,
      on_mount: [{PevSquadWeb.UserAuth, :mount_current_scope}] do
      live "/reviews/:id", ReviewLive.Show, :show
      live "/gallery/:slug", GalleryLive.Album, :show
    end
  end

  scope "/", PevSquadWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PevSquadWeb.UserAuth, :mount_current_scope}, PevSquadWeb.AuthTitles] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
