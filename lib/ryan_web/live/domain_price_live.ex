defmodule RyanWeb.DomainPriceLive do
  use Phoenix.LiveView
  alias Ryan.DomainApi

  @min 200_000
  @max 5_000_000
  @increments 1_000

  @clamp %{min: @min, max: @max, match: nil}

  def render(assigns), do: RyanWeb.LiveView.render("domain_price.html", assigns)

  def mount(_params, socket) do
    {:ok,
     assign(socket,
       property_input: "",
       client_id_input: "client_76f828f793fe40d5879cf2d40cfc0bc5",
       client_secret_input: "secret_74f38337117edd26a3b2ea86eae93685",
       is_searching: false,
       error: nil,
       property: nil,
       min: @clamp,
       max: @clamp
     )}
  end

  def handle_event(
        "update-input",
        %{
          "property_input" => property_input,
          "client_id_input" => client_id_input,
          "client_secret_input" => client_secret_input
        },
        socket
      ) do
    {:noreply,
     assign(socket,
       property_input: property_input,
       client_id_input: client_id_input,
       client_secret_input: client_secret_input
     )}
  end

  def handle_event("search", _params, socket) do
    property_id = DomainApi.property_id(socket.assigns.property_input)

    send(self(), {:load, property_id})

    {:noreply, assign(socket, is_searching: true, not_found: false, property: nil)}
  end

  def handle_info({:load, property_id}, socket) do
    access_token =
      DomainApi.get_access_token(
        socket.assigns.client_id_input,
        socket.assigns.client_secret_input
      )

    property_response = DomainApi.get_property(property_id, access_token)

    IO.inspect(property_response)

    case property_response.status_code do
      200 ->
        property =
          property_response.body
          |> Jason.decode!()

        send(self(), {:min_request, property, @clamp, access_token})
        send(self(), {:max_request, property, @clamp, access_token})

        {:noreply, assign(socket, property: property)}

      401 ->
        {:noreply, assign(socket, error: :denied)}

      404 ->
        {:noreply, assign(socket, error: :not_found)}

      429 ->
        {:noreply, assign(socket, error: :rate_limit)}

      _ ->
        {:noreply, assign(socket, error: :unknown)}
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
    # domain has an API call limit, wait 50ms
    Process.sleep(50)

    property
    |> DomainApi.get_properties(min, max, access_token)
    |> Enum.filter(fn data -> data["listing"]["id"] == property["id"] end)
    |> Enum.count() == 1
  end
end
