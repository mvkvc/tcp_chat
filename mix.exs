defmodule FakeSlack.MixProject do
  use Mix.Project

  def project do
    [
      app: :fake_slack,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      mod: {FakeSlack.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:ecto_sqlite3, "~> 0.10.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end
end
