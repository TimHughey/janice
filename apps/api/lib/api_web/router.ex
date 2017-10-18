defmodule ApiWeb.Router do
  use ApiWeb, :router

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

  scope "/", ApiWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
    get "/mcp", McpController, :index
    get "/mcp/:fname", McpController, :show
  end

  # Add this scope for handling API requests
  scope "/api", ApiWeb do
    pipe_through :api

    resources "/switches/lastseen", SwitchesLastSeenController, only: [:index]
  end

  # Other scopes may use custom stacks.
  # scope "/api", ApiWeb do
  #   pipe_through :api
  # end
end
