defmodule TcpChat.Server.Rooms do
  @moduledoc """
  The TcpChat.Server.Users module contains the logic for operations including rooms on the server.
  """

  require Logger
  alias TcpChat.Server.Access
  alias TcpChat.Server.Users

  def is_admin?(room, user) do
    admins = Access.get_admins(room)
    Enum.member?(admins, user)
  end

  def get_room(user) do
    Access.get_room(user)
  end

  def get_rooms do
    Access.get_rooms()
  end

  def send_message(room, message) do
    message
    |> format_message()
    |> send_to_all(room)
  end

  def send_message(room, message, user) do
    message
    |> format_message(user)
    |> send_to_except_user(room, user)
  end

  defp send_to_all(message, room) do
    room
    |> Access.get_sockets()
    |> Enum.each(fn socket -> :gen_tcp.send(socket, message) end)
  end

  defp send_to_except_user(message, room, user) do
    user_socket = Access.get_socket(user)

    room
    |> Access.get_sockets()
    |> Enum.reject(&(&1 == user_socket))
    |> Enum.each(fn socket -> :gen_tcp.send(socket, message) end)
  end

  def change_room(user, room) do
    current_room = Access.get_room(user)
    message = "#{user} has left the room."
    send_message(current_room, message, user)
    Access.change_room(user, room)
    message = "#{user} has entered the room."
    send_message(room, message, user)
  end

  def kick_user(user, kicked_user, room \\ "lobby") do
    current_room = Access.get_room(user)

    if is_admin?(current_room, user) do
      Access.change_room(kicked_user, room)
      message = "You have been kicked from `#{current_room}`."
      Users.send_message(kicked_user, message)

      message = "#{kicked_user} was kicked from `#{current_room}`."
      send_message(current_room, message)
    else
      message = "You are not an admin in `#{current_room}`."
      Users.send_message(user, message)
    end
  end

  def get_users(room) do
    Access.get_users(room)
  end

  defp format_message(message, sender \\ nil) do
    case sender do
      nil -> "ROOM: #{message}\n"
      _ -> "ROOM #{sender}: #{message}\n"
    end
  end
end
