defmodule Protohackers.TcpServer.DynamicSupervisor do
  use DynamicSupervisor

  alias Protohackers.TcpServer.Worker

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, nil, opts)
  end

  @impl true
  def init(nil) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_worker(self, handler, socket) do
    spec = {Worker, {handler, socket}}
    DynamicSupervisor.start_child(self, spec)
  end
end
