import Config

config :fake_slack,
  ecto_repos: [FakeSlack.Repo]

config :fake_slack, FakeSlack.Repo, database: ".sqlite/repo.db"

config :fake_slack,
  port: 5000,
  timeout: 300_000,
  max_users: 100,
  admin_list: []

if File.exists?("./config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
