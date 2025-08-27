defmodule Protohackers.BudgetChat do
  use Protohackers.TcpServer.Handler

  alias Protohackers.BudgetChat.Room

  require Logger

  @impl true
  def init(socket) do
    :inet.setopts(socket, packet: :line, buffer: 1024)
    ask_for_name(socket)
    {:ok, :joining}
  end

  @impl true
  def handle_data(name, _socket, :joining) when byte_size(name) > 32, do: :close

  def handle_data(name, socket, :joining) do
    name = String.trim_trailing(name)

    case Room.join(name, socket) do
      :ok ->
        {:ok, :joined}

      {:error, :exists} ->
        :close
    end
  end

  def handle_data(message, _socket, :joined) do
    if :binary.last(message) != ?\n do
      :close
    else
      :ok = Room.broadcast(message)
      {:ok, :joined}
    end
  end

  defp ask_for_name(socket) do
    Logger.info("Asking for name #{inspect(socket)}")
    :gen_tcp.send(socket, "What's your name lad?\n")
  end
end
