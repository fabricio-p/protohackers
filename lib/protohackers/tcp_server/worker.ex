defmodule Protohackers.TcpServer.Worker do
  use GenServer

  require Logger

  def start_link({handler, socket}) do
    GenServer.start_link(__MODULE__, {handler, socket})
  end

  def accept(pid), do: GenServer.call(pid, :accept, :infinity)

  @impl true
  def init({handler, root_socket}) do
    {:ok, {:accept, handler, root_socket}}
  end

  @impl true
  def handle_call(:accept, _from, {:accept, handler, root_socket}) do
    {:ok, socket} = :gen_tcp.accept(root_socket)
    Logger.debug("Accepted connection: #{inspect(socket)}")
    :inet.setopts(socket, active: :once)
    {:ok, state} = handler.init(socket)
    {:reply, :ok, {handler, socket, state}}
  end

  @impl true
  def handle_info({:tcp, socket, data}, {handler, socket, state}) do
    Logger.debug("Received(#{inspect(socket)}): #{inspect(data)}")

    case handler.handle_data(data, socket, state) do
      {:ok, state} ->
        :inet.setopts(socket, active: :once)
        {:noreply, {handler, socket, state}}

      :close ->
        Logger.debug("Closing connection: #{inspect(socket)}")
        :gen_tcp.shutdown(socket, :read_write)
        :gen_tcp.close(socket)
        {:noreply, {handler, socket, state}}
    end
  end

  def handle_info({:tcp_closed, socket}, {handler, socket, state}) do
    Logger.debug("Client closed connection: #{inspect(socket)}")
    {:ok, state} = handler.handle_close(socket, state)
    :gen_tcp.shutdown(socket, :read_write)
    :gen_tcp.close(socket)
    {:stop, :normal, {handler, socket, state}}
  end

  def handle_info(msg, socket) do
    dbg(msg)
    {:noreply, socket}
  end
end
