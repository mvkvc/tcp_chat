defmodule FakeSlack.MixProject do
  use Mix.Project

  def project do
    [
      app: :fake_slack,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {FakeSlack.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end
end
