import Config

config :tcp_chat,
  port: 5000,
  timeout: 300_000,
  max_users: 100,
  admin_list: []

if File.exists?("./config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
