defmodule Ryan.DomainApiTest do
  use ExUnit.Case

  alias Ryan.DomainApi

  test "keeps valid id" do
    assert DomainApi.property_id("2013609971") == "2013609971"
  end

  test "it removes domain url" do
    assert DomainApi.property_id(
             "https://www.domain.com.au/60-clare-place-the-gap-qld-4061-2013609971"
           ) == "2013609971"
  end
end
