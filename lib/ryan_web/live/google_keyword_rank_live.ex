defmodule RyanWeb.GoogleKeywordRankLive do
  use Phoenix.LiveView

  def render(assigns), do: RyanWeb.LiveView.render("google_keyword_rank.html", assigns)

  def mount(_params, socket) do
    {:ok, assign(socket, domain: "", keywords: "", error: nil, results: nil)}
  end

  def handle_event("submit", %{"domain" => domain, "keywords" => keywords}, socket) do
    url = "https://www.google.com/search?q=#{URI.encode(keywords)}&num=100"

    case HTTPoison.get(url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        results =
          body
          |> Floki.parse_document!()
          |> Floki.find("a")
          |> Enum.reduce([], fn node, acc -> acc ++ transform_node(node) end)

        {:noreply,
         assign(socket, error: nil, results: results, domain: domain, keywords: keywords)}

      {:ok, %HTTPoison.Response{status_code: 302}} ->
        {:error,
         assign(socket,
           error: "Google rate limit",
           results: nil,
           domain: domain,
           keywords: keywords
         )}

      {:error, error} ->
        {:error, assign(socket, error: error, results: nil, domain: domain, keywords: keywords)}
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
