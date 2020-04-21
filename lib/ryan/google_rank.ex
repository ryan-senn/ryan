defmodule Ryan.GoogleRank do
  def get_search_results(keywords) do
    url = "https://www.google.com/search?q=#{URI.encode(keywords)}&num=100"

    case HTTPoison.get(url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        results =
          body
          |> Floki.parse_document!()
          |> Floki.find("a")
          |> Enum.reduce([], fn node, acc -> acc ++ transform_node(node) end)

      {:ok, %HTTPoison.Response{status_code: 302}} ->
        {:error, "Google rate limit"}

      {:error, error} ->
        {:error, error}
    end
  end

  def get_backlinks(url, domain) do
    try do
      body = Sh.curl(url, "-L", "-S", "--compressed", "-s")

      case Floki.parse_document(body) do
        {:ok, parsed} ->
          links =
            parsed
            |> Floki.find("a[href*=\"#{domain}\"]")
            |> Enum.filter(fn link -> get_href(link) != nil end)
            |> Enum.map(fn link -> get_href(link) end)
            |> Enum.map(fn link -> %{href: link, isFollow: true} end)

          {:ok, links}

        {:error, error} ->
          {:error, error}
      end
    rescue
      _ ->
        {:error, %{url: url, error: "Unknown error"}}
    end
  end

  defp transform_node({"a", [{"href", link}], [{"div", _, [_]}, _]}) do
    uri =
      link
      |> URI.decode()
      |> String.replace("/url?q=", "")
      |> String.split("&sa=U&")
      |> Enum.at(0)
      |> URI.parse()

    [URI.to_string(uri)]
  end

  defp transform_node(_), do: []

  defp get_href({"a", attributes, _nodes}) do
    attributes
    |> Enum.filter(fn {key, value} -> key == "href" && !String.starts_with?(value, "mailto") end)
    |> get_href_help()
  end

  defp get_href_help([]), do: nil

  defp get_href_help([{key, value}]), do: value
end
