defmodule Protohackers.TcpServer.Handler do
  @callback init(socket :: :gen_tcp.socket()) ::
              {:ok, state :: any()} | {:error, reason :: any()}
  @callback handle_data(
              data :: binary(),
              socket :: :gen_tcp.socket(),
              state :: any()
            ) ::
              {:ok, state :: any()} | :close | {:error, reason :: any()}
  @callback handle_close(socket :: :gen_tcp.socket(), any()) ::
              {:ok, state :: any()} | {:error, reason :: any()}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Protohackers.TcpServer.Handler

      @doc false
      def handle_data(_data, _socket, state), do: {:ok, state}
      @doc false
      def handle_close(_socket, state), do: {:ok, state}
      defoverridable handle_data: 3, handle_close: 2
    end
  end
end
