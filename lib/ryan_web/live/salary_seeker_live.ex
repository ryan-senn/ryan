defmodule RyanWeb.SalarySeekerLive do
  use Phoenix.LiveView
  alias Ryan.SeekApi

  @min_salary 30_000
  @max_salary 200_000
  @increments 1_000

  @initial_job %{id: nil, title: nil, advertiser_id: nil}
  @initial_salary %{min: @min_salary, max: @max_salary, final: nil}

  def render(assigns), do: RyanWeb.LiveView.render("salary_seeker.html", assigns)

  def mount(_params, socket) do
    {:ok,
     assign(socket,
       input: "",
       is_searching: false,
       job_not_found: false,
       job: @initial_job,
       min_salary: @initial_salary,
       max_salary: @initial_salary
     )}
  end

  def handle_event("update-input", %{"input" => input}, socket) do
    {:noreply, assign(socket, input: input)}
  end

  def handle_event("search", _params, socket) do
    job_id = SeekApi.job_id(socket.assigns.input)

    send(self(), {:load_job, job_id})

    {:noreply, assign(socket, is_searching: true, job_not_found: false, job: @initial_job)}
  end

  def handle_info({:load_job, job_id}, socket) do
    data =
      job_id
      |> SeekApi.info_url()
      |> HTTPoison.get!()
      |> (fn response -> response.body end).()
      |> Jason.decode!()
      |> (fn json -> json["data"] end).()

    if Enum.count(data) != 1 do
      {:noreply, assign(socket, job_not_found: true)}
    else
      info = Enum.at(data, 0)

      job = %{
        id: info["id"],
        title: info["title"],
        advertiser_id: info["advertiser"]["id"]
      }

      send(self(), {:min_request, job, @initial_salary})
      send(self(), {:max_request, job, @initial_salary})

      {:noreply, assign(socket, job: job)}
    end
  end

  def handle_info({:min_request, job, salary}, socket) do
    number_to_check = number_to_check(salary)
    is_found = is_found(job, @min_salary, number_to_check)

    salary =
      if is_found do
        if salary.max == number_to_check do
          Map.put(salary, :final, salary.min)
        else
          new_salary = Map.put(salary, :max, number_to_check)
          send(self(), {:min_request, job, new_salary})
          new_salary
        end
      else
        if salary.min == number_to_check do
          Map.put(salary, :final, salary.max)
        else
          new_salary = Map.put(salary, :min, number_to_check)
          send(self(), {:min_request, job, new_salary})
          new_salary
        end
      end

    {:noreply, assign(socket, min_salary: salary)}
  end

  def handle_info({:max_request, job, salary}, socket) do
    number_to_check = number_to_check(salary)
    is_found = is_found(job, number_to_check, @max_salary)

    salary =
      if is_found do
        if salary.min == number_to_check do
          Map.put(salary, :final, salary.max)
        else
          new_salary = Map.put(salary, :min, number_to_check)
          send(self(), {:max_request, job, new_salary})
          new_salary
        end
      else
        if salary.max == number_to_check do
          Map.put(salary, :final, salary.min)
        else
          new_salary = Map.put(salary, :max, number_to_check)
          send(self(), {:max_request, job, new_salary})
          new_salary
        end
      end

    {:noreply, assign(socket, max_salary: salary)}
  end

  defp number_to_check(salary) do
    div(salary.min + salary.max, @increments * 2)
    |> round()
    |> (fn number -> number * @increments end).()
  end

  defp is_found(job, min, max) do
    SeekApi.salary_url(job, min, max)
    |> HTTPoison.get!()
    |> (fn response -> response.body end).()
    |> Jason.decode!()
    |> (fn json -> json["data"] end).()
    |> Enum.filter(fn job_data -> job_data["id"] == job.id end)
    |> Enum.count() == 1
  end
end
