defmodule FakeSlack.Server do
  use GenServer
  require Logger
  alias FakeSlack.Server.Commands
  alias FakeSlack.Server.Rooms
  alias FakeSlack.Server.Users

  defstruct listen_socket: nil,
            timeout: nil,
            users: nil,
            admins: nil,
            supervisor: nil

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([] = _opts) do
    port = Application.get_env(:fake_slack, :port, 5000)
    timeout = Application.get_env(:fake_slack, :timeout, 300_000)
    max_users = Application.get_env(:fake_slack, :max_users, 10)
    admin_list = Application.get_env(:fake_slack, :admin_list, [])

    args = [port: port, timeout: timeout, max_users: max_users, admin_list: admin_list]
    Logger.info("Starting server with arguments: #{inspect(args)}")

    {:ok, supervisor} = Task.Supervisor.start_link(max_children: max_users)

    users = Users.create_users()
    admins = Rooms.create_admins(admin_list)

    listen_opts = [
      ifaddr: {0, 0, 0, 0},
      mode: :binary,
      reuseaddr: true,
      active: false,
      exit_on_close: false
    ]

    case :gen_tcp.listen(port, listen_opts) do
      {:ok, listen_socket} ->
        Logger.info("Listening on port: #{port}.")

        state = %__MODULE__{
          listen_socket: listen_socket,
          timeout: timeout,
          users: users,
          admins: admins,
          supervisor: supervisor
        }

        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.info("Stopping server: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Logger.info("New connection: #{inspect(socket)}")

        Task.Supervisor.start_child(state.supervisor, fn ->
          handle_connection(state, socket)
        end)

        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        Logger.info("Error in handle_continue: #{inspect(reason)}")
    end
  end

  def handle_connection(state, socket) do
    :gen_tcp.send(socket, "Please enter a username: \n")

    case :gen_tcp.recv(socket, 0, state.timeout) do
      {:ok, username} ->
        username = String.trim(username)
        usernames = Users.get_users(state.users)

        if Enum.member?(usernames, username) do
          :gen_tcp.send(socket, "Username #{username} already taken.\n")
          handle_connection(state, socket)
        else
          :gen_tcp.send(socket, "Username set to #{username}.\n")
          Users.enter_server(state.users, socket, username, "lobby")

          Rooms.send_message(
            state.users,
            socket,
            "#{username} has entered the chat.\n",
            "lobby"
          )

          handle_chat(state, socket, username)
        end

      {:error, :closed} ->
        Logger.info("Connection closed.\n")

      {:error, reason} ->
        Logger.info("Error in handle_connection: #{inspect(reason)}")
    end
  end

  def handle_chat(state, socket, user) do
    case :gen_tcp.recv(socket, 0, state.timeout) do
      {:ok, message} ->
        message = String.trim(message)

        if Commands.is_command?(message) do
          room = Rooms.get_room(state.users, user)

          case Commands.run_command(state, socket, message, user, room) do
            {:ok, :continue} ->
              handle_chat(state, socket, user)

            {:ok, :exit} ->
              Users.exit_server(state.users, socket, user)
          end
        else
          Users.chat(state.users, socket, message, user)
          handle_chat(state, socket, user)
        end

      {:error, :timeout} ->
        Logger.info("User #{user} timed out.")
        Users.exit_server(state.users, socket, user)

      {:error, :closed} ->
        Logger.info("User #{user} closed connection.")
        Users.exit_server(state.users, socket, user)

      {:error, reason} ->
        Logger.info("Error in handle_chat: #{inspect(reason)}")
    end
  end
end
