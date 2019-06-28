defmodule RyanWeb.InflationCalculatorLive do
  use Phoenix.LiveView
  alias Ryan.Inflation

  @initial_price 10000
  @initial_year 2010

  def render(assigns), do: RyanWeb.LiveView.render("inflation_calculator.html", assigns)

  def mount(_params, socket) do
    inflation = Inflation.calculate(@initial_price, @initial_year)

    {:ok, assign(socket, price: @initial_price, year: @initial_year, inflation: inflation)}
  end

  def handle_event("update-form", %{"price" => price, "year" => year}, socket) do
    price = String.to_integer(price)
    year = String.to_integer(year)

    inflation = Inflation.calculate(price, year)

    {:noreply, assign(socket, price: price, year: year, inflation: inflation)}
  end
end
