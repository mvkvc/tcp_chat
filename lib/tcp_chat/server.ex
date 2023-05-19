defmodule TcpChat.Server do
  @moduledoc """
  The TcpChat.Server module contains the main server logic for handling connections and user interactions.
  """

  use GenServer
  require Logger
  alias TcpChat.Server.Access
  alias TcpChat.Server.Commands
  alias TcpChat.Server.Users

  defstruct listen_socket: nil,
            supervisor: nil,
            timeout: nil

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([] = _opts) do
    port = Application.get_env(:tcp_chat, :port, 5000)
    timeout = Application.get_env(:tcp_chat, :timeout, 300_000)
    max_users = Application.get_env(:tcp_chat, :max_users, 10)
    admin_list = Application.get_env(:tcp_chat, :admin_list, [])

    args = [port: port, timeout: timeout, max_users: max_users, admin_list: admin_list]
    Logger.info("Starting server with arguments: #{inspect(args)}")

    {:ok, supervisor} = Task.Supervisor.start_link(max_children: max_users)

    Access.init(admins: admin_list)

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
          supervisor: supervisor,
          timeout: timeout
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

  defp handle_connection(state, socket) do
    :gen_tcp.send(socket, "Please enter a username: \n")

    case :gen_tcp.recv(socket, 0, state.timeout) do
      {:ok, username} ->
        username = String.trim(username)
        usernames = Users.get_users()

        if Enum.member?(usernames, username) do
          :gen_tcp.send(socket, "Username #{username} already taken.\n")
          handle_connection(state, socket)
        else
          :gen_tcp.send(socket, "Username set to #{username}.\n")
          :gen_tcp.send(socket, "Welcome to the server, #{username}!\n")
          Users.enter_server(username, socket, "lobby")

          handle_chat(state, socket, username)
        end

      {:error, :closed} ->
        Logger.info("Connection closed.\n")

      {:error, reason} ->
        Logger.info("Error in handle_connection: #{inspect(reason)}")
    end
  end

  defp handle_chat(state, socket, user) do
    case :gen_tcp.recv(socket, 0, state.timeout) do
      {:ok, message} ->
        message = String.trim(message)
        handle_message(state, socket, user, message)

      {:error, reason} when reason in [:timeout, :closed] ->
        Logger.info("User #{user} disconnected.")
        Users.exit_server(user)

      {:error, reason} ->
        Logger.info("Error in handle_chat: #{inspect(reason)}")
    end
  end

  defp handle_message(state, socket, user, message) do
    if Commands.is_command?(message) do
      handle_command(state, socket, user, message)
    else
      Users.chat(user, message)
      handle_chat(state, socket, user)
    end
  end

  defp handle_command(state, socket, user, command) do
    case Commands.handle_command(user, command) do
      {:ok, :continue} ->
        handle_chat(state, socket, user)

      {:ok, :exit} ->
        message = "Goodbye, #{user}!"
        Users.send_message(user, message)
        Users.exit_server(user)
        :gen_tcp.close(socket)
    end
  end
end
