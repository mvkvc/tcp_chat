defmodule FakeSlack.Repo do
  use Ecto.Repo, otp_app: :fake_slack, adapter: Ecto.Adapters.SQLite3
end
