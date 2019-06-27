defmodule Ryan.SeekApiTest do
  use ExUnit.Case

  alias Ryan.SeekApi

  test "keeps valid id" do
    assert SeekApi.job_id("39307591") == "39307591"
  end

  test "it removes seek url" do
    assert SeekApi.job_id("https://www.seek.com.au/job/39307591") == "39307591"
  end

  test "it removes extra params" do
    assert SeekApi.job_id(
             "https://www.seek.com.au/job/39307591?searchrequesttoken=c3035450-f42c-4d9f-815d-452c8c77a9f6&type=standout"
           ) == "39307591"
  end
end
