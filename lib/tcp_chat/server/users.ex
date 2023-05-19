defmodule TcpChat.Server.Users do
  @moduledoc """
  The TcpChat.Server.Users module contains the logic for operations including users on the server.
  """

  require Logger
  alias TcpChat.Server.Access
  alias TcpChat.Server.Rooms

  def get_users do
    Access.get_users()
  end

  def send_message(user, message, sender \\ nil) do
    message = format_message(message, sender)
    socket = Access.get_socket(user)
    :gen_tcp.send(socket, message)
  end

  def enter_server(user, socket, room \\ "lobby") do
    Access.enter_server(user, socket, room)
    message = "#{user} has joined the server."
    Rooms.send_message(room, message, user)
  end

  def exit_server(user) do
    message = "#{user} has left the server."
    room = Access.get_room(user)
    Rooms.send_message(room, message, user)
    Access.exit_server(user)
  end

  def chat(user, message) do
    {user, message}
    room = Access.get_room(user)
    Rooms.send_message(room, message, user)
  end

  defp format_message(message, sender) do
    case sender do
      nil -> "MESSAGE: #{message}\n"
      _ -> "MESSAGE #{sender}: #{message}\n"
    end
  end
end
