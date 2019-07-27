defmodule Ryan.Inflation do
  def start_year() do
    1950
  end

  # source: https://www.rateinflation.com/inflation-rate/australia-historical-inflation-rate?start-year=1950&end-year=2019
  def list() do
    [
      10,
      18.2,
      17.3,
      4.9,
      1.6,
      1.5,
      6.1,
      2.9,
      0,
      2.8,
      4.1,
      1.3,
      0,
      1.3,
      2.5,
      3.7,
      2.4,
      3.5,
      3.4,
      3.3,
      3.2,
      6.1,
      5.8,
      9.1,
      15.8,
      15.1,
      13.1,
      12.2,
      7.9,
      9.1,
      10.5,
      9.5,
      11.1,
      10.3,
      4,
      6.5,
      9.2,
      8.4,
      7.3,
      7.4,
      7.5,
      3.1,
      1,
      1.7,
      2,
      4.7,
      2.6,
      0.3,
      0.7,
      1.5,
      4.5,
      4.3,
      3.1,
      2.7,
      2.3,
      2.7,
      3.5,
      2.3,
      4.4,
      1.7,
      2.9,
      3.3,
      1.7,
      2.5,
      2.5,
      1.5,
      1.3,
      1.9,
      1.9
    ]
  end

  def calculate(price, start_year) do
    start_index = abs(start_year() - start_year)
    end_index = Enum.count(list())

    slice =
      list()
      |> Enum.slice(start_index..end_index)

    slice
    |> Enum.scan(price, &calculate_year/2)
    |> Enum.zip(slice)
  end

  defp calculate_year(percent, price) do
    round(price + price * percent / 100)
  end
end
