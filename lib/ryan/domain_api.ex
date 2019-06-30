defmodule Ryan.DomainApi do

  def property_id(input) do
    String.slice(input, -10, 10)
  end

  def get_access_token(domain_api_client_id, domain_api_secret) do
    HTTPoison.post!(
      "https://auth.domain.com.au/v1/connect/token",
      URI.encode_query(%{
        grant_type: "client_credentials",
        scope: "api_listings_read"
      }),
      [
        {"Content-Type", "application/x-www-form-urlencoded"},
        {"Authorization",
         "Basic #{Base.encode64("#{domain_api_client_id}:#{domain_api_secret}")}"}
      ]
    )
    |> (fn response -> response.body end).()
    |> Jason.decode!()
    |> (fn json -> json["access_token"] end).()
  end

  def get_property(property_id, access_token) do
    HTTPoison.get!(
      "https://api.domain.com.au/v1/listings/#{property_id}",
      [{"Authorization", "Bearer #{access_token}"}]
    )
  end

  def get_properties(property, min, max, access_token) do
    HTTPoison.post!(
      "https://api.domain.com.au/v1/listings/residential/_search",
      Jason.encode!(%{
        listingType: "Sale",
        minPrice: min,
        maxPrice: max,
        pageSize: 100,
        propertyTypes: property["propertyTypes"],
        minBedrooms: property["bedrooms"],
        maxBedrooms: property["bedrooms"],
        minBathrooms: property["bathrooms"],
        maxBathrooms: property["bathrooms"],
        locations: [
          %{
            state: "",
            region: "",
            area: "",
            suburb: property["addressParts"]["suburb"],
            postCode: property["addressParts"]["postcode"],
            includeSurroundingSuburbs: false
          }
        ]
      }),
      [{"Authorization", "Bearer #{access_token}"}, {"Content-Type", "text/json"}]
    )
    |> (fn response -> response.body end).()
    |> Jason.decode!()
  end
end
