defmodule TcpChat.Server.Access do
  @moduledoc """
  This module is responsible for implementing data access functions.
  """

  @doc """
  Initialize the data store.
  """
  def init(opt \\ []) do
    admin_list = Keyword.get(opt, :admins, [])

    :ets.new(:users, [:named_table, :public])
    :ets.new(:admins, [:named_table, :public])

    Enum.each(admin_list, fn {room, admins} ->
      :ets.insert(:admins, {to_string(room), admins})
    end)
  end

  @doc """
  Return true if the user is online.
  """
  def is_online?(user) do
    :ets.member(:users, user)
  end

  @doc """
  Return all online users or all users in a given room.
  """
  def get_users(room \\ nil) do
    match = if room, do: {:"$1", :_, room}, else: {:"$1", :_, :_}

    case :ets.match(:users, match) do
      [] ->
        []

      users ->
        users
        |> Enum.map(fn [user] -> user end)
        |> Enum.sort()
    end
  end

  @doc """
  Return all users in a given room.
  """
  def get_admins(room) do
    case :ets.lookup(:admins, room) do
      [] -> []
      [{_room, admins}] -> admins
    end
  end

  @doc """
  Return the socket for a given user.
  """
  def get_socket(user) do
    case :ets.lookup_element(:users, user, 2) do
      :undefined -> nil
      socket -> socket
    end
  end

  @doc """
  Return the sockets for a given room.
  """
  def get_sockets(room) do
    case :ets.match(:users, {:_, :"$1", room}) do
      [] -> []
      sockets -> Enum.map(sockets, fn [socket] -> socket end)
    end
  end

  @doc """
  Return the room for a given user.
  """
  def get_room(user) do
    case :ets.lookup_element(:users, user, 3) do
      :undefined -> nil
      room -> room
    end
  end

  @doc """
  Return all rooms.
  """
  def get_rooms do
    case :ets.match(:users, {:_, :_, :"$1"}) do
      [] ->
        []

      rooms ->
        rooms
        |> Enum.uniq()
        |> Enum.map(fn [room] -> room end)
        |> Enum.sort()
    end
  end

  @doc """
  Change the room for a given user.
  """
  def change_room(user, room) do
    :ets.update_element(:users, user, {3, room})
  end

  @doc """
  Add a new user and their associated data to the data store.
  """
  def enter_server(user, socket, room) do
    :ets.insert(:users, {user, socket, room})
  end

  @doc """
  Remove a user and their associated data from the data store.
  """
  def exit_server(user) do
    :ets.delete(:users, user)
  end
end
