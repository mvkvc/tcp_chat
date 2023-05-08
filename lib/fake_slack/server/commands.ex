defmodule FakeSlack.Server.Commands do
  alias FakeSlack.Server.Rooms
  alias FakeSlack.Server.Users

  def is_command?(message) do
    message
    |> String.trim()
    |> String.starts_with?("/")
  end

  def run_command(state, socket, message, user, room) do
    case String.trim(message) do
      "/q" ->
        {:ok, :exit}

      "/kick " <> kicked_user ->
        if Rooms.is_admin?(state.admins, room, user) do
          Rooms.kick_user(state.users, user, kicked_user, room)
        else
          Users.send_message(state.users, user, "You are not an admin in `#{room}`.\n")
        end

        {:ok, :continue}

      "/exit" ->
        Rooms.change_room(state.users, user, "lobby")
        {:ok, :continue}

      "/here" ->
        user_list =
          Rooms.list_users(state.users, room)
          |> Enum.filter(fn room_user -> room_user != user end)
          |> Enum.sort()

        if user_list == [] do
          message = "No other users in `#{room}`.\n"
          Users.send_message(state.users, user, message)
        else
          user_list_string = Enum.join(user_list, "\n")
          message = "Users in `#{room}`:\n#{user_list_string}\n"
          Users.send_message(state.users, user, message)
        end

        {:ok, :continue}

      "/peek " <> room ->
        user_list = Rooms.list_users(state.users, room)

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

        Users.send_message(state.users, user, message)
        {:ok, :continue}

      "/room" ->
        Users.send_message(state.users, user, "You are in `#{room}`.\n")
        {:ok, :continue}

      "/rooms" ->
        rooms = Rooms.list_rooms(state.users) |> Enum.sort()
        rooms_string = Enum.join(rooms, "\n")
        message = "Rooms:\n#{rooms_string}\n"
        Users.send_message(state.users, user, message)
        {:ok, :continue}

      "/switch " <> room ->
        Rooms.change_room(state.users, user, room)
        {:ok, :continue}

      "/users" ->
        users_list =
          Users.get_usernames(state.users)
          |> Enum.filter(fn username -> username != user end)
          |> Enum.sort()

        message =
          if users_list == [] do
            "No other users online.\n"
          else
            users_list_string = Enum.join(users_list, "\n")
            "Users online:\n#{users_list_string}\n"
          end

        Users.send_message(state.users, user, message)
        {:ok, :continue}

      "/delay " <> rest ->
        [delay, message] = String.split(rest, " ", parts: 2)

        case String.to_integer(delay) do
          delay when delay > 0 ->
            message = String.trim(message)

            Task.Supervisor.start_child(state.supervisor, fn ->
              :timer.sleep(delay * 1000)

              Users.chat(state.users, socket, message, user)
            end)

          _ ->
            Users.send_message(state.users, user, "Invalid delay #{delay}.\n")
        end

        {:ok, :continue}

      _ ->
        Users.send_message(state.users, user, "Invalid command #{message}.\n")
        {:ok, :continue}
    end
  end
end
