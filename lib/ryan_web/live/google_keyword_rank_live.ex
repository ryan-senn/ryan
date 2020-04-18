defmodule RyanWeb.GoogleKeywordRankLive do
  use Phoenix.LiveView

  def render(assigns), do: RyanWeb.LiveView.render("google_keyword_rank.html", assigns)

  def mount(_params, socket) do
    {:ok, assign(socket, domain: "", keywords: "", error: nil, results: nil)}
  end

  def handle_event("submit", %{"domain" => domain, "keywords" => keywords}, socket) do
    url = "https://www.google.com/search?q=#{URI.encode(keywords)}"

    {:noreply, socket}

    case fetch([], url) do
      {:ok, results} ->
        {:noreply,
         assign(socket, error: nil, results: results, domain: domain, keywords: keywords)}

      {:error, error} ->
        {:noreply, assign(socket, error: error, domain: domain, keywords: keywords)}
    end
  end

  defp fetch(acc, url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        links =
          body
          |> Floki.parse_document!()
          |> Floki.find("a")

        results = Enum.reduce(links, [], fn node, acc -> acc ++ transform_node(node) end)

        next = "https://www.google.com" <> find_next(links)

        acc = acc ++ results

        if Enum.count(acc) < 100 do
          Process.sleep(Enum.random(100..1000))
          fetch(acc, next)
        else
          {:ok, acc}
        end

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

  defp find_next([]), do: nil

  defp find_next(links) do
    [head | tail] = links
    find_next(head, tail)
  end

  defp find_next({"a", attributes, _}, links) do
    if Enum.any?(attributes, fn attribute -> attribute == {"aria-label", "Next page"} end) do
      {_, value} = Enum.find(attributes, fn {key, _} -> key == "href" end)

      value
    else
      find_next(links)
    end
  end
end
