defmodule RyanWeb.DomainPriceLive do
  use Phoenix.LiveView
  alias Ryan.DomainApi

  @min 100_000
  @max 10_000_000
  @increments 1_000

  @clamp %{min: @min, max: @max, match: nil}

  def render(assigns), do: RyanWeb.LiveView.render("domain_price.html", assigns)

  def mount(_params, socket) do
    {:ok,
     assign(socket,
       input: "",
       is_searching: false,
       not_found: false,
       property: nil,
       min: @clamp,
       max: @clamp
     )}
  end

  def handle_event("update-input", %{"input" => input}, socket) do
    {:noreply, assign(socket, input: input)}
  end

  def handle_event("search", _params, socket) do
    property_id = DomainApi.property_id(socket.assigns.input)

    send(self(), {:load, property_id})

    {:noreply, assign(socket, is_searching: true, not_found: false, property: nil)}
  end

  def handle_info({:load, property_id}, socket) do
    access_token = DomainApi.get_access_token()

    try do
      property = DomainApi.get_property(property_id, access_token)

      send(self(), {:min_request, property, @clamp, access_token})
      send(self(), {:max_request, property, @clamp, access_token})

      {:noreply, assign(socket, property: property)}
    rescue
      Jason.DecodeError ->
        {:noreply, assign(socket, not_found: true)}
    end
  end

  def handle_info({:min_request, property, clamp, access_token}, socket) do
    number_to_check = number_to_check(clamp)
    is_found = is_found(property, @min, number_to_check, access_token)

    clamp =
      if is_found do
        if clamp.max == number_to_check do
          Map.put(clamp, :match, clamp.min)
        else
          new_clamp = Map.put(clamp, :max, number_to_check)
          send(self(), {:min_request, property, new_clamp, access_token})
          new_clamp
        end
      else
        if clamp.min == number_to_check do
          Map.put(clamp, :match, clamp.max)
        else
          new_clamp = Map.put(clamp, :min, number_to_check)
          send(self(), {:min_request, property, new_clamp, access_token})
          new_clamp
        end
      end

    {:noreply, assign(socket, min: clamp)}
  end

  def handle_info({:max_request, property, clamp, access_token}, socket) do
    number_to_check = number_to_check(clamp)
    is_found = is_found(property, number_to_check, @max, access_token)

    clamp =
      if is_found do
        if clamp.min == number_to_check do
          Map.put(clamp, :match, clamp.max)
        else
          new_clamp = Map.put(clamp, :min, number_to_check)
          send(self(), {:max_request, property, new_clamp, access_token})
          new_clamp
        end
      else
        if clamp.max == number_to_check do
          Map.put(clamp, :match, clamp.min)
        else
          new_clamp = Map.put(clamp, :max, number_to_check)
          send(self(), {:max_request, property, new_clamp, access_token})
          new_clamp
        end
      end

    {:noreply, assign(socket, max: clamp)}
  end

  defp number_to_check(clamp) do
    div(clamp.min + clamp.max, @increments * 2)
    |> round()
    |> (fn number -> number * @increments end).()
  end

  defp is_found(property, min, max, access_token) do
    property
    |> DomainApi.get_properties(min, max, access_token)
    |> Enum.filter(fn data -> data["listing"]["id"] == property["id"] end)
    |> Enum.count() == 1
  end
end
