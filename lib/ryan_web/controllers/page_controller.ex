defmodule RyanWeb.PageController do
  use RyanWeb, :controller
  alias Ryan.GoogleRank

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

  def uses(conn, _params) do
    render(conn, "uses.html")
  end

  def google_rank(conn, _params) do
    render(conn, "google_rank.html", csrfToken: get_csrf_token())
  end

  def google_rank_search(conn, %{"keywords" => keywords}) do
    json(conn, GoogleRank.get_search_results(keywords))
  end

  def google_rank_backlinks(conn, %{"url" => url, "domain" => domain}) do
    case GoogleRank.get_backlinks(url, domain) do
      {:ok, links} -> json(conn, links)
      {:error, error} -> json(conn, [])
    end
  end
end
