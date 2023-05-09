defmodule FakeSlack.Server.Commands do
  @moduledoc """
  The FakeSlack.Server.Users module contains the logic for interpreting and executing user commands.
  """

  alias FakeSlack.Server.Rooms
  alias FakeSlack.Server.Users

  def is_command?(message) do
    message
    |> String.trim()
    |> String.starts_with?("/")
  end

  def run_command(state, socket, message, user, room) do
    message = String.trim(message)
    handle_command(state, socket, message, user, room)
  end

  defp handle_command(_state, _socket, "/q", _user, _room), do: {:ok, :exit}

  defp handle_command(state, socket, "/time", user, _room) do
    {{year, month, day}, {hour, minute, second}} = :calendar.local_time()

    time_message =
      "The local server time is #{hour}:#{minute}:#{second} on #{day}/#{month}/#{year}.\n"

    Users.send_message(state.users, user, time_message, socket)

    {:ok, :continue}
  end

  defp handle_command(state, socket, "/kick " <> kicked_user, user, room) do
    if Rooms.is_admin?(state.admins, room, user) do
      Rooms.kick_user(state.users, user, kicked_user, room)
    else
      Users.send_message(state.users, user, "You are not an admin in `#{room}`.\n", socket)
    end

    {:ok, :continue}
  end

  defp handle_command(state, _socket, "/exit", user, _room) do
    Rooms.change_room(state.users, user, "lobby")

    {:ok, :continue}
  end

  defp handle_command(state, socket, "/here", user, room) do
    user_list =
      Rooms.list_users(state.users, room)
      |> Enum.filter(fn room_user -> room_user != user end)
      |> Enum.sort()

    if user_list == [] do
      message = "No other users in `#{room}`.\n"
      Users.send_message(state.users, user, message, socket)
    else
      user_list_string = Enum.join(user_list, "\n")
      message = "Users in `#{room}`:\n#{user_list_string}\n"
      Users.send_message(state.users, user, message, socket)
    end

    {:ok, :continue}
  end

  defp handle_command(state, socket, "/peek " <> peeked_room, user, _room) do
    user_list = Rooms.list_users(state.users, peeked_room)

    message =
      if user_list == [] do
        "No users in `#{peeked_room}`.\n"
      else
        user_list_string =
          user_list
          |> Enum.sort()
          |> Enum.join("\n")

        "Users in `#{peeked_room}`:\n#{user_list_string}\n"
      end

    Users.send_message(state.users, user, message, socket)

    {:ok, :continue}
  end

  defp handle_command(state, socket, "/room", user, room) do
    Users.send_message(state.users, user, "You are in `#{room}`.\n", socket)

    {:ok, :continue}
  end

  defp handle_command(state, socket, "/rooms", user, _room) do
    rooms = Rooms.list_rooms(state.users) |> Enum.sort()
    rooms_string = Enum.join(rooms, "\n")
    message = "Rooms:\n#{rooms_string}\n"
    Users.send_message(state.users, user, message, socket)

    {:ok, :continue}
  end

  defp handle_command(state, _socket, "/switch " <> new_room, user, _room) do
    Rooms.change_room(state.users, user, new_room)
    {:ok, :continue}
  end

  defp handle_command(state, socket, "/users", user, _room) do
    users_list =
      Users.get_users(state.users)
      |> Enum.filter(fn username -> username != user end)
      |> Enum.sort()

    message =
      if users_list == [] do
        "No other users online.\n"
      else
        users_list_string = Enum.join(users_list, "\n")
        "Users online:\n#{users_list_string}\n"
      end

    Users.send_message(state.users, user, message, socket)

    {:ok, :continue}
  end

  defp handle_command(state, socket, "/delay " <> rest, user, _room) do
    [delay_string | message_parts] = String.split(rest, " ", parts: 2)
    message = Enum.join(message_parts, " ")

    case Integer.parse(delay_string) do
      {delay_int, _} when delay_int > 0 and message != "" ->
        send_delayed_message(state, socket, message, user, delay_int)

      _ ->
        handle_invalid_delay(state, user, delay_string, message, socket)
    end

    {:ok, :continue}
  end

  defp handle_command(state, socket, message, user, _room) do
    Users.send_message(state.users, user, "Invalid command #{message}.\n", socket)
    {:ok, :continue}
  end

  defp send_delayed_message(state, socket, message, user, delay) do
    message = String.trim(message)

    Task.Supervisor.start_child(state.supervisor, fn ->
      :timer.sleep(delay * 1000)

      Users.chat(state.users, socket, message, user)
    end)
  end

  defp handle_invalid_delay(state, user, delay_string, message, socket) do
    error_message =
      if message == "" do
        "Invalid argument #{delay_string}."
      else
        "Invalid delay #{delay_string}."
      end

    Users.send_message(state.users, user, error_message, socket)
  end
end
