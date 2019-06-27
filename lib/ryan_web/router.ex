defmodule RyanWeb.Router do
  use RyanWeb, :router
  alias Phoenix.LiveView

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RyanWeb do
    pipe_through :browser

    get "/", PageController, :index

    live "/salary-seeker", SalarySeekerLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", RyanWeb do
  #   pipe_through :api
  # end
end
