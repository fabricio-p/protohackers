defmodule Protohackers.EchoServer do
  use Protohackers.TcpServer.Handler

  @impl true
  def init(_socket), do: {:ok, nil}

  @impl true
  def handle_data(data, socket, nil) do
    :gen_tcp.send(socket, data)
    {:ok, nil}
  end
end
