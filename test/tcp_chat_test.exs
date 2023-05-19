defmodule TcpChat.ServerTest do
  use ExUnit.Case

  @port Application.compile_env(:tcp_chat, :port, 5000)
  @timeout_client 1000
  @timeout_flush 10
  @sleep 100

  defp connect(port) do
    :gen_tcp.connect(~c"localhost", port, mode: :binary, active: false)
  end

  defp sign_in(port, username) do
    {:ok, socket} = connect(port)
    {:ok, "Please enter a username: \n"} = :gen_tcp.recv(socket, 0, @timeout_client)
    :gen_tcp.send(socket, "#{username}\n")
    {:ok, "Username set to" <> _rest} = :gen_tcp.recv(socket, 0, @timeout_client)
    {:ok, "Welcome to the server, " <> _rest} = :gen_tcp.recv(socket, 0, @timeout_client)

    socket
  end

  defp flush(socket) do
    case :gen_tcp.recv(socket, 0, @timeout_flush) do
      {:ok, _message} -> :ok
      {:error, :timeout} -> :ok
      _ -> :error
    end
  end

  test "user can connect and set a username" do
    username = "marko"

    {:ok, socket} = connect(@port)

    assert {:ok, "Please enter a username: \n"} = :gen_tcp.recv(socket, 0, @timeout_client)

    :gen_tcp.send(socket, "#{username}\n")
    target_message = "Username set to #{username}.\n"
    {:ok, message} = :gen_tcp.recv(socket, 0, @timeout_client)
    assert target_message == message

    :gen_tcp.close(socket)
  end

  test "server rejects already taken username" do
    username = "marko"

    {:ok, socket1} = connect(@port)
    target_message = "Please enter a username: \n"
    {:ok, message} = :gen_tcp.recv(socket1, 0, @timeout_client)
    assert target_message == message

    :gen_tcp.send(socket1, "#{username}\n")
    target_message = "Username set to #{username}.\n"
    {:ok, message} = :gen_tcp.recv(socket1, 0, @timeout_client)
    assert target_message == message

    {:ok, socket2} = connect(@port)
    target_message = "Please enter a username: \n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, @timeout_client)
    assert target_message == message

    :gen_tcp.send(socket2, "#{username}\n")
    username_taken = "Username #{username} already taken.\n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, @timeout_client)
    assert username_taken == message

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end

  test "user can change room" do
    socket = sign_in(@port, "marko")

    :ok = :gen_tcp.send(socket, "/room\n")
    assert {:ok, "MESSAGE: You are in `lobby`.\n"} = :gen_tcp.recv(socket, 0, @timeout_client)

    :ok = :gen_tcp.send(socket, "/switch room1\n")
    :ok = :gen_tcp.send(socket, "/room\n")
    assert {:ok, "MESSAGE: You are in `room1`.\n"} = :gen_tcp.recv(socket, 0, @timeout_client)

    :gen_tcp.close(socket)
  end

  test "chat messages delivered in same room" do
    user1 = "marko"
    user2 = "pawel"

    message1 = "good morning"
    message2 = "good evening"

    socket1 = sign_in(@port, user1)
    socket2 = sign_in(@port, user2)

    :ok = flush(socket2)
    :ok = :gen_tcp.send(socket1, message1)
    morning_message = "ROOM #{user1}: #{message1}\n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, @timeout_client)
    assert morning_message == message

    :ok = flush(socket1)
    :ok = :gen_tcp.send(socket2, message2)
    night_message = "ROOM #{user2}: #{message2}\n"
    assert {:ok, message} = :gen_tcp.recv(socket1, 0, @timeout_client)
    assert night_message == message

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end

  test "chat messages not delivered in diff room" do
    user1 = "marko"
    user2 = "pawel"

    message1 = "good morning"
    message2 = "good evening"

    socket1 = sign_in(@port, user1)
    socket2 = sign_in(@port, user2)

    :ok = flush(socket1)
    :ok = :gen_tcp.send(socket1, message1)
    target_message = "ROOM #{user1}: #{message1}\n"
    {:ok, message} = :gen_tcp.recv(socket2, 0, @timeout_client)
    assert target_message == message

    :ok = :gen_tcp.send(socket2, "/switch room1\n")

    :ok = flush(socket1)
    :ok = :gen_tcp.send(socket2, message2)
    assert {:error, :timeout} = :gen_tcp.recv(socket1, 0, @timeout_client)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end

  test "get list of rooms" do
    socket1 = sign_in(@port, "marko")
    socket2 = sign_in(@port, "pawel")
    socket3 = sign_in(@port, "dan")

    :ok = :gen_tcp.send(socket2, "/switch room1\n")
    :ok = :gen_tcp.send(socket3, "/switch room2\n")

    :timer.sleep(@sleep)

    :ok = flush(socket1)
    :ok = :gen_tcp.send(socket1, "/rooms\n")

    assert {:ok, "MESSAGE: Rooms:\nlobby\nroom1\nroom2\n"} =
             :gen_tcp.recv(socket1, 0, @timeout_client)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
    :gen_tcp.close(socket3)
  end

  test "peek into other rooms" do
    socket1 = sign_in(@port, "marko")
    socket2 = sign_in(@port, "pawel")
    socket3 = sign_in(@port, "dan")

    :ok = :gen_tcp.send(socket2, "/switch room1\n")
    :ok = :gen_tcp.send(socket3, "/switch room1\n")

    :timer.sleep(@sleep)

    :ok = :gen_tcp.send(socket1, "/peek room1\n")

    :ok = flush(socket1)

    assert {:ok, "MESSAGE: Users in `room1`:\ndan\npawel\n"} =
             :gen_tcp.recv(socket1, 0, @timeout_client)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
    :gen_tcp.close(socket3)
  end

  test "kick user" do
    socket1 = sign_in(@port, "pawel")
    socket2 = sign_in(@port, "sasa")

    :ok = :gen_tcp.send(socket1, "/switch elixir\n")
    :ok = :gen_tcp.send(socket2, "/switch elixir\n")

    :timer.sleep(@sleep)

    :ok = flush(socket1)
    :ok = flush(socket2)
    :ok = :gen_tcp.send(socket1, "/kick sasa\n")

    assert {:ok, "MESSAGE: You are not an admin in `elixir`.\n"} =
             :gen_tcp.recv(socket1, 0, @timeout_client)

    :ok = :gen_tcp.send(socket2, "/kick pawel\n")

    assert {:ok, "MESSAGE: You have been kicked from `elixir`.\n"} =
             :gen_tcp.recv(socket1, 0, @timeout_client)

    assert {:ok, "ROOM: pawel was kicked from `elixir`.\n"} =
             :gen_tcp.recv(socket2, 0, @timeout_client)

    :gen_tcp.close(socket1)
    :gen_tcp.close(socket2)
  end
end
