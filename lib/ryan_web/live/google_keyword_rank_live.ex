defmodule RyanWeb.GoogleKeywordRankLive do
  use Phoenix.LiveView

  @default_state %{
    domain: "tt.edu.au",
    keywords: "White Card Gold Coast",
    error: nil,
    results: nil,
    backlinks: nil
  }

  def render(assigns), do: RyanWeb.LiveView.render("google_keyword_rank.html", assigns)

  def mount(_params, socket) do
    {:ok, assign(socket, @default_state)}
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

        send(self(), {:get_backlinks, domain, results})

        {:noreply, set(socket, results: results, domain: domain, keywords: keywords)}

      {:ok, %HTTPoison.Response{status_code: 302}} ->
        {:noreply, set(socket, error: "Google rate limit", domain: domain, keywords: keywords)}

      {:error, error} ->
        {:noreply, set(socket, error: error, domain: domain, keywords: keywords)}
    end
  end

  def handle_info({:get_backlinks, domain, results}, socket) do
    backlinks =
      results
      |> Enum.map(fn result ->
        Task.async(fn -> crawl_backlinks(result, domain) end)
      end)
      |> Enum.map(fn task -> Task.await(task, 30_000) end)
      |> Enum.filter(fn result ->
        case result do
          {:ok, %{uri: uri, links: links}} ->
            links != []

          {:error, _} ->
            false
        end
      end)
      |> Enum.map(fn {:ok, %{uri: uri, links: links}} ->
        %{uri: uri, links: Enum.map(links, &get_href/1)}
      end)

    {:noreply, assign(socket, backlinks: backlinks)}
  end

  defp transform_node({"a", [{"href", link}], [{"div", _, [_]}, _]}) do
    uri =
      link
      |> URI.decode()
      |> String.replace("/url?q=", "")
      |> String.split("&sa=U&")
      |> Enum.at(0)
      |> URI.parse()

    [uri]
  end

  defp transform_node(_), do: []

  defp crawl_backlinks(%URI{} = uri, domain) do
    try do
      body = Sh.curl(URI.to_string(uri), "-L", "-S", "--compressed", "-s")

      case Floki.parse_document(body) do
        {:ok, parsed} ->
          links =
            parsed
            |> Floki.find("a[href*=\"#{domain}\"]")
            |> Enum.filter(fn link -> get_href(link) != nil end)

          {:ok, %{uri: uri, links: links}}

        {:error, error} ->
          {:error, %{uri: uri, error: error}}
      end
    rescue
      _ ->
        {:error, %{uri: uri, error: "Unknown error"}}
    end
  end

  defp get_href({"a", attributes, _nodes}) do
    attributes
    |> Enum.filter(fn {key, value} -> key == "href" && !String.starts_with?(value, "mailto") end)
    |> get_href_help()
  end

  defp get_href_help([]), do: nil

  defp get_href_help([{key, value}]), do: value

  defp set(socket, args) do
    assign(
      socket,
      Enum.reduce(args, @default_state, fn {key, value}, acc ->
        Map.put(acc, key, value)
      end)
    )
  end
end
