ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Ryan.Repo, :manual)

Code.load_file("test/ryan/seek_api.exs")
