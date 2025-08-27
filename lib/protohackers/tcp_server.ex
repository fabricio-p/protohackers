defmodule Protohackers.TcpServer do
  alias Protohackers.TcpServer.{DynamicSupervisor, Worker}

  require Logger

  defstruct [:socket, :supervisor, :handler]

  def start_link(opts) do
    port = opts[:port]
    supervisor = Keyword.fetch!(opts, :supervisor)
    handler = Keyword.fetch!(opts, :handler)
    listen_options = Keyword.get(opts, :listen_options, [])

    pid =
      spawn_link(__MODULE__, :entry_point, [
        port,
        supervisor,
        handler,
        listen_options
      ])

    {:ok, pid}
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc false
  def entry_point(port, supervisor, handler, listen_options) do
    {:ok, socket} =
      :gen_tcp.listen(port, [
        :binary
        | Keyword.merge(
            [active: true, reuseaddr: true],
            listen_options
          )
      ])

    Logger.info("Listening on port #{port}: #{inspect(socket)}")

    state = %__MODULE__{
      socket: socket,
      supervisor: supervisor,
      handler: handler
    }

    loop(state)
  end

  defp loop(%{socket: socket, supervisor: supervisor, handler: handler} = state) do
    try do
      :ok = accept_and_serve(socket, supervisor, handler)
    catch
      k, e ->
        Logger.error(
          "TCP server: #{inspect(k)}, #{inspect(e)}\n#{inspect(__STACKTRACE__)}"
        )
    end

    loop(state)
  end

  defp accept_and_serve(socket, supervisor, handler) do
    case DynamicSupervisor.start_worker(supervisor, handler, socket) do
      {:ok, pid} ->
        Worker.accept(pid)

      {:ok, pid, _info} ->
        Worker.accept(pid)

      :ignore ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
    |> IO.inspect(label: :accept_and_serve)
  end
end
