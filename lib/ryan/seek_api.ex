defmodule Ryan.SeekApi do
  def job_id(input) do
    input
    |> String.replace("https://www.seek.com.au/job/", "")
    |> String.split("?")
    |> Enum.at(0)
  end

  def info_url(job_id) do
    url(%{jobid: job_id})
  end

  def salary_url(job, min, max) do
    url(%{
        keywords: job.title,
        advertiserid: job.advertiser_id,
        salaryrange: "#{min}-#{max}",
        sourcesystem: "houston"
      })
  end

  defp url(params) do
    "https://chalice-search-api.cloud.seek.com.au/search?#{URI.encode_query(params)}"
  end
end
