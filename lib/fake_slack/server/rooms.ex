defmodule FakeSlack.Server.Rooms do
  @moduledoc """
  The FakeSlack.Server.Users module contains the logic for operations including rooms on the server.
  """

  require Logger
  alias FakeSlack.Server.Users

  def create_admins(admin_list \\ []) do
    ets = :ets.new(:admins, [:public])

    Enum.each(admin_list, fn {room, admins} ->
      :ets.insert(ets, {to_string(room), admins})
    end)

    ets
  end

  def is_admin?(admins, room, user) do
    match_result = :ets.match(admins, {room, :"$1"})

    case match_result do
      [] ->
        false

      [[admins]] ->
        Enum.member?(admins, user)
    end
  end

  def send_message(users, socket, message, room, user \\ nil) do
    {sockets, message} =
      if user do
        [[user]] = :ets.match(users, {socket, :"$1", :_})
        sockets = :ets.match(users, {:"$1", :_, room})
        {sockets, format_message(message, user)}
      else
        {[], format_message(message)}
      end

    Enum.each(sockets, fn [other_socket] ->
      if other_socket != socket do
        :gen_tcp.send(other_socket, message)
      end
    end)
  end

  def change_room(users, user, room) do
    case :ets.match(users, {:"$1", user, :"$2"}) do
      [[socket, current_room]] ->
        :ets.match_delete(users, {socket, user, current_room})
        :ets.insert(users, {socket, user, room})

      _ ->
        Logger.error("No match for #{user}.")
    end
  end

  def kick_user(users, user, kicked, room \\ "lobby") do
    message = "#{user} has kicked you from the room.\n"
    Users.send_message(users, kicked, message)
    message = "#{kicked} was kicked from the room.\n"
    Users.send_message(users, user, message)
    change_room(users, kicked, room)
  end

  def list_users(users, room) do
    users = :ets.match(users, {:_, :"$1", room})

    if Enum.empty?(users) do
      users
    else
      Enum.map(users, fn [user] -> user end)
    end
  end

  def list_rooms(users) do
    users
    |> :ets.match({:_, :_, :"$1"})
    |> Enum.uniq()
    |> Enum.map(fn [room] -> room end)
  end

  def get_room(users, user) do
    [[room]] = :ets.match(users, {:_, user, :"$1"})
    room
  end

  defp format_message(message, user \\ nil) do
    if user do
      "MESSAGE #{user}: " <> message <> "\n"
    else
      "MESSAGE: " <> message <> "\n"
    end
  end
end
