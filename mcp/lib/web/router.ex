defmodule Web.Router do
  use Web, :router
  require Ueberauth

  pipeline :auth do
    plug Ueberauth
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :browser_session do
    plug Web.VerifySessionPipeline
  end

  pipeline :browser_authenticated do
    plug Web.AuthAccessPipeline
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Web.ApiAuthAccessPipeline
  end

  scope "/mercurial/auth", Web do
    pipe_through [:browser]

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback  # used by GitHub
    post "/:provider/callback", AuthController, :callback # used by Identity
  end

  scope "/mercurial/mcp", Web do
    pipe_through [:browser, :browser_session, :browser_authenticated]

    get "/", McpController, :index
    get "/detail/:type", McpController, :show
  end

  scope "/mercurial/mcp/api", Web do
    pipe_through [:api]
    resources "/detail/:type", McpDetailController, only: [:index, :show]
    get "/mixtank", MixtankController, :manage
    get "/mixtank/all", MixtankController, :all
    resources "/sensor", SensorController, only: [:delete]
  end

  scope "/mercurial", Web do
    pipe_through [:browser, :browser_session]

    get "/", HomeController, :index
    delete "/logout", AuthController, :delete

  end
end
