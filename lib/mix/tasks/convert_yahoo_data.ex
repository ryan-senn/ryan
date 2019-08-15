defmodule Mix.Tasks.ConvertYahooData do

  def run(args) do
    csv_path = Enum.at(args, 0)

    [name, _extenstion] =
      String.split(csv_path, ".")

    json_path =
      "#{name}.json"

    content =
      csvToJson(csv_path)

    File.write!(json_path, content)
  end

  defp csvToJson(path) do
    path
    |> File.stream!()
    |> CSV.decode()
    |> Enum.drop(1)
    |> Enum.filter(fn {:ok, row} ->
      Enum.at(row, 1) != "null" && Enum.at(row, 1) != Enum.at(row, 4)
    end)
    |> Enum.map(fn {:ok, row} ->
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
        date: Enum.at(row, 0),
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
  end
end
