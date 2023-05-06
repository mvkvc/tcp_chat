defmodule FakeSlack.Server.Commands do
  alias FakeSlack.Server.Rooms
  alias FakeSlack.Server.Users

  def is_command?(message) do
    message = String.trim(message)
    String.starts_with?(message, "/") or message == "q"
  end

  def run_command(users, admins, message, user, room) do
    case String.trim(message) do
      "q" ->
        {:ok, :exit}

      "/kick " <> kicked_user ->
        if Rooms.is_admin?(admins, room, user) do
          Rooms.kick_user(users, user, kicked_user, room)
        else
          Users.send_message(users, user, "You are not an admin in `#{room}`.\n")
        end

        {:ok, :continue}

      "/exit" ->
        Rooms.change_room(users, user, "lobby")
        {:ok, :continue}

      "/here" ->
        user_list =
          Rooms.list_users(users, room)
          |> Enum.filter(fn room_user -> room_user != user end)
          |> Enum.sort()

        if user_list == [] do
          message = "No other users in `#{room}`.\n"
          Users.send_message(users, user, message)
        else
          user_list_string = Enum.join(user_list, "\n")
          message = "Users in `#{room}`:\n#{user_list_string}\n"
          Users.send_message(users, user, message)
        end

        {:ok, :continue}

      "/peek " <> room ->
        user_list = Rooms.list_users(users, room)

        message =
          if user_list == [] do
            "No users in `#{room}`.\n"
          else
            user_list_string =
              user_list
              |> Enum.sort()
              |> Enum.join("\n")

            "Users in `#{room}`:\n#{user_list_string}\n"
          end

        Users.send_message(users, user, message)
        {:ok, :continue}

      "/room" ->
        Users.send_message(users, user, "You are in `#{room}`.\n")
        {:ok, :continue}

      "/rooms" ->
        rooms = Rooms.list_rooms(users) |> Enum.sort()
        rooms_string = Enum.join(rooms, "\n")
        message = "Rooms:\n#{rooms_string}\n"
        Users.send_message(users, user, message)
        {:ok, :continue}

      "/switch " <> room ->
        Rooms.change_room(users, user, room)
        {:ok, :continue}

      _ ->
        Users.send_message(users, user, "Invalid command #{message}.\n")
        {:ok, :continue}
    end
  end
end
