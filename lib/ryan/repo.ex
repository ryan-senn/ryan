defmodule Ryan.Repo do
  use Ecto.Repo,
    otp_app: :ryan,
    adapter: Ecto.Adapters.Postgres
end
