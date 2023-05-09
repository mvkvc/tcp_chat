defmodule FakeSlack.Application do
  @moduledoc """
  The FakeSlack.Application module is the entry point for the application.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FakeSlack.Repo,
      FakeSlack.Server
    ]

    opts = [strategy: :one_for_one, name: FakeSlack.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)
  end
end
