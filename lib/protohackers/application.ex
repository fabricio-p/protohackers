defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:protohackers, :port)

    children =
      case Application.get_env(:protohackers, :problem) do
        "echo_server" ->
          [
            dynamic_supervisor_spec(EchoServer),
            tcp_server_spec(EchoServer, port)
          ]

        "prime_time" ->
          [
            dynamic_supervisor_spec(PrimeTime),
            tcp_server_spec(PrimeTime, port, packet: :line)
          ]

        "means_to_an_end" ->
          [
            dynamic_supervisor_spec(MeansToAnEnd),
            tcp_server_spec(MeansToAnEnd, port)
          ]
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_all,
      auto_shutdown: :any_significant,
      name: Protohackers.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  defp dynamic_supervisor_spec(name),
    do:
      {Protohackers.TcpServer.DynamicSupervisor,
       name: dynamic_supervisor_name(name), max_restarts: 0}

  defp dynamic_supervisor_name(name),
    do: Module.concat([Protohackers, name, DynamicSupervisor])

  defp tcp_server_spec(name, port, opts \\ []),
    do:
      {Protohackers.TcpServer,
       port: port,
       supervisor: dynamic_supervisor_name(name),
       handler: Module.concat([Protohackers, name]),
       listen_options: opts}
end
