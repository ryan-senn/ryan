defmodule RyanWeb.GoogleKeywordRankLive do
  use Phoenix.LiveView

  def render(assigns), do: RyanWeb.LiveView.render("google_keyword_rank.html", assigns)

  def mount(_params, socket) do
    {:ok, assign(socket, domain: "", keywords: "", error: nil, results: nil)}
  end

  def handle_event("submit", %{"domain" => domain, "keywords" => keywords}, socket) do
    url = "https://www.google.com/search?q=#{URI.encode(keywords)}&num=100"

    case fetch(url) do
      {:ok, results} ->
        {:noreply,
         assign(socket, error: nil, results: results, domain: domain, keywords: keywords)}

      {:error, error} ->
        {:noreply, assign(socket, error: error, domain: domain, keywords: keywords)}
    end
  end

  defp fetch(url) do
    case HTTPoison.get(url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        results =
          body
          |> Floki.parse_document!()
          |> Floki.find("a")
          |> Enum.reduce([], fn node, acc -> acc ++ transform_node(node) end)

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

  defp transform_node(_), do: []
end
