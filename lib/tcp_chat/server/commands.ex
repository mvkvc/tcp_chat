defmodule TcpChat.Server.Commands do
  @moduledoc """
  The TcpChat.Server.Users module contains the logic for interpreting and executing user commands.
  """

  require Logger
  alias TcpChat.Server.Rooms
  alias TcpChat.Server.Users

  def is_command?(message) do
    message
    |> String.trim()
    |> String.starts_with?("/")
  end

  def handle_command(_user, "/q"), do: {:ok, :exit}

  def handle_command(user, "/time") do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()

    message = "The local server time is #{hour}:#{minute}:#{second} on #{day}/#{month}/#{year}."

    Users.send_message(user, message)

    {:ok, :continue}
  end

  def handle_command(user, "/kick " <> kicked_user) do
    Rooms.kick_user(user, kicked_user)

    {:ok, :continue}
  end

  def handle_command(user, "/exit") do
    Rooms.change_room(user, "lobby")

    {:ok, :continue}
  end

  def handle_command(user, "/here") do
    room = Rooms.get_room(user)

    message =
      case Rooms.get_users(room) do
        [^user] ->
          "No other users in `#{room}`."

        user_list ->
          user_list_string = Enum.join(user_list, "\n")
          "Users in `#{room}`:\n#{user_list_string}"
      end

    Users.send_message(user, message)

    {:ok, :continue}
  end

  def handle_command(user, "/peek " <> room) do
    message =
      case Rooms.get_users(room) do
        [] ->
          "No users in `#{room}`."

        user_list ->
          user_list_string = Enum.join(user_list, "\n")
          "Users in `#{room}`:\n#{user_list_string}"
      end

    Users.send_message(user, message)

    {:ok, :continue}
  end

  def handle_command(user, "/room") do
    room = Rooms.get_room(user)
    message = "You are in `#{room}`."
    Users.send_message(user, message)

    {:ok, :continue}
  end

  def handle_command(user, "/rooms") do
    rooms = Rooms.get_rooms()
    rooms_string = Enum.join(rooms, "\n")
    message = "Rooms:\n#{rooms_string}"
    Users.send_message(user, message)

    {:ok, :continue}
  end

  def handle_command(user, "/switch " <> room) do
    Rooms.change_room(user, room)

    {:ok, :continue}
  end

  def handle_command(user, "/users") do
    users_list = Users.get_users()

    message =
      case users_list do
        [^user] ->
          "No other users online."

        users_list ->
          users_list_string = Enum.join(users_list, "\n")
          "Users online:\n#{users_list_string}"
      end

    Users.send_message(user, message)

    {:ok, :continue}
  end

  def handle_command(user, "/delay " <> rest) do
    message_parts = String.split(rest, " ", parts: 2)

    case message_parts do
      [delay_string, message | _] ->
        case Integer.parse(delay_string) do
          {delay, _} when delay > 0 and message != "" ->
            send_delayed_message(user, message, delay)

          _ ->
            message = "Invalid delay amount #{delay_string}."
            Users.send_message(user, message)
        end

      _ ->
        message = "Invalid delay command. Please provide a delay and a message."
        Users.send_message(user, message)
    end

    {:ok, :continue}
  end

  def handle_command(user, command) do
    message = "Invalid command #{command}."
    Users.send_message(user, message)

    {:ok, :continue}
  end

  defp send_delayed_message(user, message, delay) do
    delay_ms = delay * 1000
    room = Rooms.get_room(user)

    Task.start(fn ->
      :timer.sleep(delay_ms)
      Rooms.send_message(room, message, user)
    end)
  end
end
