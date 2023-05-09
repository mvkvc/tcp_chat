import Config

config :fake_slack,
  ecto_repos: [FakeSlack.Repo]

config :fake_slack, FakeSlack.Repo, database: ".sqlite/repo.test.db"

config :fake_slack,
  timeout: 5_000,
  admin_list: [elixir: ["sasa", "jose"]]
