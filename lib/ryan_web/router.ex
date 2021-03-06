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
    live "/domain-price", DomainPriceLive
    live "/inflation-calculator", InflationCalculatorLive
    get "/powerball", PageController, :powerball
    get "/gold-lotto", PageController, :gold_lotto
    get "/daily-chart", PageController, :daily_chart
    get "/daily-chart/:chart", PageController, :daily_chart
    get "/uses", PageController, :uses

    live "/google-keyword-rank", GoogleKeywordRankLive

    get "/google-rank", PageController, :google_rank
    post "/google-rank/search", PageController, :google_rank_search
    post "/google-rank/backlinks", PageController, :google_rank_backlinks
  end

  # Other scopes may use custom stacks.
  # scope "/api", RyanWeb do
  #   pipe_through :api
  # end
end
