defmodule Protohackers.UnusualDatabase do
  use GenServer

  require Logger

  def start_link(opts) do
    port = Keyword.fetch!(opts, :port)
    GenServer.start_link(__MODULE__, port)
  end

  @impl true
  def init(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true, buffer: 1000])
    state = {socket, %{}}
    {:ok, state}
  end

  @impl true
  def handle_info(
        {:udp, socket, peer_ip, peer_port, "version"},
        {socket, map} = state
      ) do
    Logger.debug(
      "received version request " <>
        "(#{inspect(peer_ip)}:#{inspect(peer_port)}): #{inspect(packet)}"
    )

    :ok = respond(socket, peer_ip, peer_port, "version", "0xfab KV store 0.1")
    {:ok, state}
  end

  @impl true
  def handle_info({:udp, socket, peer_ip, peer_port, packet}, {socket, map}) do
    Logger.debug(
      "packet received " <>
        "(#{inspect(peer_ip)}:#{inspect(peer_port)}): #{inspect(packet)}"
    )

    case :binary.match(packet, "=") do
      {start, _n} ->
        <<key::binary-size(start), ?=, value::binary>> = packet
        map = Map.put(map, key, value)
        {:noreply, {socket, map}}

      :nomatch ->
        key = packet
        value = Map.get(map, key, "")
        :ok = respond(socket, peer_ip, peer_port, key, value)
        {:noreply, {socket, map}}
    end
  end

  defp respond(socket, ip, port, key, value),
    do: :gen_udp.send(socket, ip, port, "#{key}=#{value}")
end
