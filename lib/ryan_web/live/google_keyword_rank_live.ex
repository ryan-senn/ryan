defmodule RyanWeb.GoogleKeywordRankLive do
  use Phoenix.LiveView

  def render(assigns), do: RyanWeb.LiveView.render("google_keyword_rank.html", assigns)

  def mount(_params, socket) do
    {:ok, assign(socket, error: nil, results: nil)}
  end

  def handle_event("submit", %{"domain" => domain, "keywords" => keywords}, socket) do
    url = "https://www.google.com/search?q=#{URI.encode(keywords)}"

    results =
      0..9
      |> Enum.map(fn i ->
        Task.async(fn -> fetch(url, i) end)
      end)
      |> Enum.map(&Task.await/1)

    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      results =
        results
        |> Enum.flat_map(fn {:ok, results} -> results end)

      {:noreply, assign(socket, results: results, domain: domain)}
    else
      {:noreply, assign(socket, error: "One or more pages couldn't load")}
    end
  end

  defp fetch(url, i) do
    case HTTPoison.get(url <> "&start=#{i * 10}") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        results =
          body
          |> Floki.parse_document!()
          |> Floki.find("a")
          |> Enum.reduce([], fn node, acc ->
            acc ++ transform_node(node)
          end)

        {:ok, results}

      {:ok, %HTTPoison.Response{status_code: 302}} ->
        {:error, "Google rate limit"}

      {:error, error} ->
        {:error, error}
    end
  end

  defp transform_node({"a", [{"href", link}], [{"div", _, [_]}, _]}) do
    uri =
      link
      |> String.replace("/url?q=", "")
      |> String.split("&sa=U&")
      |> Enum.at(0)
      |> URI.parse()

    [uri]
  end

  defp transform_node(_) do
    []
  end
end
