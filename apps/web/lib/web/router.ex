defmodule Web.Router do
  use Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Web do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/mercurial", McpController, :index
    get "/mercurial/:fname", McpController, :index
  end

  # Other scopes may use custom stacks.
  scope "/mercurial/api", Web do
    pipe_through :api
    resources "/switches/lastseen", SwitchesLastSeenController,
      only: [:index]
  end
end
