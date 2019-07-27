defmodule RyanWeb.PageController do
  use RyanWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def powerball(conn, _params) do
    render(conn, "powerball.html")
  end
end
