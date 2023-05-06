defmodule FakeSlack.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {FakeSlack.Server, []}
    ]

    opts = [strategy: :one_for_one, name: FakeSlack.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)
  end
end
