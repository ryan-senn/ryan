defmodule Ryan.DomainApiTest do
  use ExUnit.Case

  alias Ryan.DomainApi

  test "keeps valid id" do
    assert DomainApi.property_id("2015383723") == "2015383723"
  end

  test "it removes domain url" do
    assert DomainApi.property_id(
             "https://www.domain.com.au/1-teroma-street-the-gap-qld-4061-2015383723"
           ) == "2015383723"
  end
end
