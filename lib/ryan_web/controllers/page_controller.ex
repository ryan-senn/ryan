defmodule RyanWeb.PageController do
  use RyanWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def powerball(conn, _params) do
    render(conn, "powerball.html")
  end

  def asx200(conn, _params) do
    data =
      "./lib/ryan/asx200.csv"
      |> File.stream!()
      |> CSV.decode()
      |> Enum.drop(1)
      |> Enum.filter(fn {:ok, row} ->
        Enum.at(row, 1) != "null" && Enum.at(row, 1) != Enum.at(row, 4)
      end)
      |> Enum.map(fn {:ok, row} ->
        date =
          row
          |> Enum.at(0)
          |> String.split("-")
          |> Enum.reverse
          |> Enum.join("/")

        {open, _} =
          row
          |> Enum.at(1)
          |> Float.parse()

        {close, _} =
          row
          |> Enum.at(4)
          |> Float.parse()

        diff = round(100 / open * (open - close) * 100)

        %{
          date: date,
          open: open,
          close: close,
          diff:
            if diff < 0 do
              abs(diff)
            else
              diff - diff * 2
            end
        }
      end)
      |> Jason.encode!()

    render(conn, "asx200.html", data: data)
  end
end
