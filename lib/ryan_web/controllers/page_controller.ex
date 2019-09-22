defmodule RyanWeb.PageController do
  use RyanWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def powerball(conn, _params) do
    render(conn, "powerball.html")
  end

  def gold_lotto(conn, _params) do
    render(conn, "gold_lotto.html")
  end

  def daily_chart(conn, %{"chart" => chart}) do
    render(conn, "daily_chart.html", data: File.read!("./lib/daily_chart_data/#{chart}.json"))
  end

  def daily_chart(conn, _params) do
    render(conn, "daily_chart.html", data: nil)
  end
end
