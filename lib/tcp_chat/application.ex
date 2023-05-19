defmodule TcpChat.Application do
  @moduledoc """
  The TcpChat.Application module is the entry point for the application.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TcpChat.Server
    ]

    opts = [strategy: :one_for_one, name: TcpChat.Supervisor]
    {:ok, _pid} = Supervisor.start_link(children, opts)
  end
end
