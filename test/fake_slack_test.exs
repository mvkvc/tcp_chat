defmodule FakeSlack.ServerTest do
  use ExUnit.Case

  defp connect(port) do
    :gen_tcp.connect(~c"localhost", port, mode: :binary, active: false)
  end

  defp user_sign_in(port, username) do
    {:ok, socket} = connect(port)
    {:ok, _message} = :gen_tcp.recv(socket, 0, 5_000)
    :gen_tcp.send(socket, "#{username}\n")
    {:ok, _message} = :gen_tcp.recv(socket, 0, 5_000)
    {:ok, _message} = :gen_tcp.recv(socket, 0, 5_000)

    socket
  end

  test "user can connect and set a username" do
    username = "marko"
    {:ok, socket} = connect(5000)

    assert {:ok, "Please enter a username: \n"} = :gen_tcp.recv(socket, 0, 5_000)

    :gen_tcp.send(socket, "#{username}\n")
    target_message = "Username set to #{username}.\n"
    {:ok, message} = :gen_tcp.recv(socket, 0, 5_000)
    assert target_message == message
    :gen_tcp.close(socket)
  end

  test "server rejects already taken username" do
    username = "marko"

    {:ok, socket1} = :gen_tcp.connect(~c"localhost", 5000, mode: :binary, active: false)
    target_message = "Please enter a username: \n"
    {:ok, message} = :gen_tcp.recv(socket1, 0, 5_000)
    assert target_message == message

    :gen_tcp.send(socket1, "#{username}\n")
    target_message = "Username set to #{username}.\n"
    {:ok, message} = :gen_tcp.recv(socket1, 0, 5_000)
    assert target_message == message

    {:ok, socket2} = :gen_tcp.connect(~c"localhost", 5000, mode: :binary, active: false)
    target_message = "Please enter a username: \n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, 5_000)
    assert target_message == message

    :gen_tcp.send(socket2, "#{username}\n")
    username_taken = "Username #{username} already taken.\n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, 5_000)
    assert username_taken == message

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end

  test "user can change room" do
    socket = user_sign_in(5000, "marko")

    :ok = :gen_tcp.send(socket, "/room\n")
    assert {:ok, "You are in `lobby`.\n"} = :gen_tcp.recv(socket, 0, 5_000)

    :ok = :gen_tcp.send(socket, "/switch room1\n")
    :ok = :gen_tcp.send(socket, "/room\n")
    assert {:ok, "You are in `room1`.\n"} = :gen_tcp.recv(socket, 0, 5_000)

    :gen_tcp.close(socket)
  end

  test "chat messages delivered in same room" do
    user1 = "marko"
    user2 = "pawel"

    message1 = "good morning"
    message2 = "good evening"

    socket1 = user_sign_in(5000, user1)
    socket2 = user_sign_in(5000, user2)

    :ok = :gen_tcp.send(socket1, message1)
    morning_message = "MESSAGE #{user1}: #{message1}\n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, 5_000)
    assert morning_message == message

    :ok = :gen_tcp.send(socket2, message2)
    night_message = "MESSAGE #{user2}: #{message2}\n"
    assert {:ok, message} = :gen_tcp.recv(socket1, 0, 5_000)
    assert night_message == message

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end

  test "chat messages not delivered in diff room" do
    user1 = "marko"
    user2 = "pawel"

    message1 = "good morning"
    message2 = "good evening"

    socket1 = user_sign_in(5000, user1)
    socket2 = user_sign_in(5000, user2)

    :ok = :gen_tcp.send(socket1, message1)
    target_message = "MESSAGE #{user1}: #{message1}\n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, 5_000)
    assert target_message == message

    :ok = :gen_tcp.send(socket2, "/switch room1\n")
    :ok = :gen_tcp.send(socket2, message2)
    assert {:error, :timeout} = :gen_tcp.recv(socket1, 0, 100)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end

  test "get list of rooms" do
    socket1 = user_sign_in(5000, "marko")
    socket2 = user_sign_in(5000, "pawel")
    socket3 = user_sign_in(5000, "dan")

    :ok = :gen_tcp.send(socket2, "/switch room1\n")
    :ok = :gen_tcp.send(socket3, "/switch room2\n")

    :timer.sleep(100)

    :ok = :gen_tcp.send(socket1, "/rooms\n")

    assert {:ok, "Rooms:\nlobby\nroom1\nroom2\n"} = :gen_tcp.recv(socket1, 0, 5_000)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
    :gen_tcp.close(socket3)
  end

  test "/peek into other rooms" do
    socket1 = user_sign_in(5000, "marko")
    socket2 = user_sign_in(5000, "pawel")
    socket3 = user_sign_in(5000, "dan")

    :ok = :gen_tcp.send(socket2, "/switch room1\n")
    :ok = :gen_tcp.send(socket3, "/switch room1\n")

    :timer.sleep(100)

    :ok = :gen_tcp.send(socket1, "/peek room1\n")

    assert {:ok, "Users in `room1`:\ndan\npawel\n"} = :gen_tcp.recv(socket1, 0, 5_000)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
    :gen_tcp.close(socket3)
  end

  test "kick user" do
    socket1 = user_sign_in(5000, "pawel")
    socket2 = user_sign_in(5000, "sasa")

    :ok = :gen_tcp.send(socket1, "/switch elixir\n")
    :ok = :gen_tcp.send(socket2, "/switch elixir\n")

    :timer.sleep(100)

    :ok = :gen_tcp.send(socket1, "/kick sasa\n")

    assert {:ok, "You are not an admin in `elixir`.\n"} = :gen_tcp.recv(socket1, 0, 5_000)

    :ok = :gen_tcp.send(socket2, "/kick pawel\n")

    assert {:ok, "pawel was kicked from the room.\n"} = :gen_tcp.recv(socket2, 0, 5_000)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end
end
