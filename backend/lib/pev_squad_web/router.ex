defmodule PevSquadWeb.Router do
  use PevSquadWeb, :router

  import PevSquadWeb.UserAuth
  import PevSquadWeb.API.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PevSquadWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PevSquadWeb.Locale
    plug :fetch_current_scope_for_user
  end

  # RSS readers send all sorts of Accept headers, so no content negotiation.
  pipeline :feed do
    plug :fetch_session
    plug PevSquadWeb.Locale
  end

  # /api/v1: the mobile app and staff tools (DESIGN.md §7). No session or
  # cookies; the caller comes from the bearer token.
  pipeline :api do
    plug :accepts, ["json"]
    plug PevSquadWeb.Locale, session: false
    plug :fetch_api_scope
    plug OpenApiSpex.Plug.PutApiSpec, module: PevSquadWeb.API.Spec
  end

  scope "/", PevSquadWeb do
    pipe_through :browser

    live_session :public,
      on_mount: [PevSquadWeb.Locale, {PevSquadWeb.UserAuth, :mount_current_scope}] do
      live "/", HomeLive.Index, :index
      live "/events", EventLive.Index, :index
      live "/events/:slug", EventLive.Show, :show
      live "/about", AboutLive.Index, :index
      live "/community", CommunityLive.Index, :index
      live "/community/:slug", CommunityLive.Show, :show
      live "/partners/:slug", PartnerLive.Show, :show
      live "/reviews", ReviewLive.Index, :index
      live "/gallery", GalleryLive.Index, :index
      live "/models/:slug", ModelLive.Show, :show
      live "/news", PostLive.Index, :news
      live "/news/:slug", PostLive.Show, :news
      live "/articles", PostLive.Index, :articles
      live "/articles/:slug", PostLive.Show, :article
      live "/for-sale", ListingLive.Index, :index
    end

    # The Featured Riders page is switched off for now (DESIGN.md decision 14).
    get "/riders", PageController, :riders

    get "/locale/:locale", PageController, :locale
  end

  scope "/", PevSquadWeb do
    pipe_through :feed

    get "/feed.xml", FeedController, :index
  end

  # Fetched by Apple's CDN, which sends no particular Accept header.
  scope "/.well-known", PevSquadWeb do
    get "/apple-app-site-association", WellKnownController, :apple_app_site_association
  end

  scope "/admin", PevSquadWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user]

    live_session :staff,
      on_mount: [PevSquadWeb.Locale, {PevSquadWeb.UserAuth, :require_staff}] do
      live "/", Dashboard, :index
      live "/events", EventLive.Index, :index
      live "/events/new", EventLive.Form, :new
      live "/events/:id/edit", EventLive.Form, :edit
      live "/members", MemberLive.Index, :index
      live "/riders", RiderLive.Index, :index
      live "/riders/new", RiderLive.Edit, :new
      live "/riders/:id/edit", RiderLive.Edit, :edit
      live "/reviews", ReviewLive.Queue, :index
      live "/models", ModelLive.Index, :index
      live "/albums", AlbumLive.Index, :index
      live "/albums/new", AlbumLive.Form, :new
      live "/albums/:id/edit", AlbumLive.Form, :edit
      live "/photos", PhotoLive.Queue, :index
      live "/reports", ReportLive.Index, :index
      live "/partners", PartnerLive.Index, :index
      live "/partners/new", PartnerLive.Form, :new
      live "/partners/:id/edit", PartnerLive.Form, :edit
      live "/posts", PostLive.Index, :index
      live "/posts/new", PostLive.Form, :new
      live "/posts/:id/edit", PostLive.Form, :edit
      live "/listings", ListingLive.Queue, :index
      live "/api-tokens", ApiTokenLive.Index, :index
    end
  end

  scope "/api/v1" do
    pipe_through :api

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  # Public reads for the app. A token is optional; with one, the caller's
  # blocks apply and listing contacts are included.
  scope "/api/v1", PevSquadWeb.API, as: :api do
    pipe_through :api

    get "/home", HomeController, :show
    get "/events", EventController, :index
    get "/events/:slug", EventController, :show
    get "/posts", PostController, :index
    get "/posts/:slug", PostController, :show
    get "/listings", ListingController, :index
    get "/listings/:id", ListingController, :show
    get "/community", CommunityController, :show
    get "/riders", CommunityController, :riders
    get "/riders/:slug", CommunityController, :rider
    get "/partners/:slug", CommunityController, :partner
    get "/albums", AlbumController, :index
    get "/albums/:slug", AlbumController, :show
  end

  scope "/api/v1", PevSquadWeb.API, as: :api_me do
    pipe_through [:api, :require_api_user]

    get "/me", MeController, :show
    patch "/me", MeController, :update
    delete "/me", MeController, :delete
    get "/me/deletion", MeController, :deletion

    get "/reports/reasons", SafetyController, :reasons
    post "/reports", SafetyController, :report
    get "/blocks", SafetyController, :blocks
    post "/blocks", SafetyController, :block
    delete "/blocks/:user_id", SafetyController, :unblock
    put "/me/profile", MeController, :profile
    put "/me/avatar", MeController, :avatar
  end

  scope "/api/v1/auth", PevSquadWeb.API, as: :api_auth do
    pipe_through :api

    post "/password", AuthController, :password
    post "/magic-link", AuthController, :request_link
    post "/exchange", AuthController, :exchange
    post "/refresh", AuthController, :refresh
    post "/logout", AuthController, :logout
  end

  # Staff tools (the `pev` CLI). Drafts only; publishing stays in /admin.
  scope "/api/v1/admin", PevSquadWeb.API.Admin, as: :api_admin do
    pipe_through [:api, :require_api_staff]

    resources "/posts", PostController, only: [:index, :show, :create, :update]
    post "/posts/:id/cover", PostController, :cover
    resources "/events", EventController, only: [:index, :show, :create, :update]
    get "/partners", PartnerController, :index
    post "/uploads", UploadController, :create
  end

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
      get "/swaggerui", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi"
    end
  end

  ## Authentication routes

  scope "/", PevSquadWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        PevSquadWeb.Locale,
        {PevSquadWeb.UserAuth, :require_authenticated},
        PevSquadWeb.AuthTitles
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/profile", UserLive.Profile, :edit
      live "/reviews/new", ReviewLive.Form, :new
      live "/group-rides/new", GroupRideLive.Form, :new
      live "/group-rides/:id/edit", GroupRideLive.Form, :edit
      live "/reviews/:id/edit", ReviewLive.Form, :edit
      live "/gallery/:slug/upload", GalleryLive.Upload, :new
      live "/report/:type/:id", ReportLive.New, :new
      live "/for-sale/new", ListingLive.Form, :new
      live "/for-sale/mine", ListingLive.Mine, :index
      live "/for-sale/:id/edit", ListingLive.Form, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  # After the authenticated routes so that /reviews/new (and /for-sale/new,
  # /for-sale/mine) aren't taken as an id.
  scope "/", PevSquadWeb do
    pipe_through :browser

    live_session :public_reviews,
      on_mount: [PevSquadWeb.Locale, {PevSquadWeb.UserAuth, :mount_current_scope}] do
      live "/reviews/:id", ReviewLive.Show, :show
      live "/gallery/:slug", GalleryLive.Album, :show
      live "/for-sale/:id", ListingLive.Show, :show
    end
  end

  scope "/", PevSquadWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        PevSquadWeb.Locale,
        {PevSquadWeb.UserAuth, :mount_current_scope},
        PevSquadWeb.AuthTitles
      ] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
