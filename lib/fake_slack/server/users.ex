defmodule FakeSlack.Server.Users do
  @moduledoc """
  The FakeSlack.Server.Users module contains the logic for operations including users on the server.
  """

  require Logger
  alias FakeSlack.Server.Rooms

  def create_users do
    :ets.new(:users, [:public])
  end

  def get_users(users) do
    users
    |> :ets.match({:_, :"$1", :_})
    |> Enum.map(fn [user] -> user end)
  end

  def send_message(users, user, message) do
    case :ets.match(users, {:"$1", user, :_}) do
      [[socket]] ->
        message = String.trim(message) <> "\n"
        :gen_tcp.send(socket, message)

      _ ->
        Logger.error("No match for #{user}.")
    end
  end

  def enter_server(users, socket, user, room \\ "lobby") do
    message = "Welcome to FakeSlack, #{user}!"
    connect_user(users, socket, user, room)
    send_message(users, user, message)
  end

  def exit_server(users, socket, user) do
    message = "Disconnecting from the server.\n"
    send_message(users, user, message)
    disconnect_user(users, socket, user)
  end

  def chat(users, socket, message, user) do
    [[room]] = :ets.match(users, {:_, user, :"$1"})
    Rooms.send_message(users, socket, message, room, user)
  end

  def connect_user(users, socket, user, room) do
    :ets.insert(users, {socket, user, room})
  end

  def disconnect_user(users, socket, user) do
    :ok = :gen_tcp.close(socket)
    :ets.match_delete(users, {:_, user, :_})
  end
end
