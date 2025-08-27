defmodule Protohackers.BudgetChat.Room do
  use GenServer

  require Logger

  @enforce_keys [:process_map, :name_set]
  defstruct @enforce_keys

  def start_link(_otps) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def join(name, socket),
    do: GenServer.call(__MODULE__, {:join, self(), name, socket})

  def broadcast(message),
    do: GenServer.cast(__MODULE__, {:broadcast, self(), message})

  @impl true
  def init(_opts),
    # NOTE: Maybe use an ETS table for `process_map`
    do: {:ok, %__MODULE__{process_map: %{}, name_set: MapSet.new()}}

  @impl true
  def handle_call(
        {:join, pid, name, socket},
        _from,
        %{process_map: process_map, name_set: name_set} = state
      ) do
    if MapSet.member?(name_set, name) do
      {:reply, {:error, :exists}, state}
    else
      monitor_ref = :erlang.monitor(:process, pid)

      {member_names, member_sockets} =
        process_map
        |> Map.values()
        |> Enum.map(fn {_ref, name, socket} -> {name, socket} end)
        |> Enum.unzip()

      Enum.each(member_sockets, &notify_user_joining(&1, name))
      inform_about_current_members(socket, member_names)

      process_map = Map.put(process_map, pid, {monitor_ref, name, socket})
      name_set = MapSet.put(name_set, name)
      state = %{state | process_map: process_map, name_set: name_set}

      Logger.info("#{name} joined: #{inspect(member_names)}")

      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_cast(
        {:broadcast, pid, message},
        %{process_map: process_map} = state
      ) do
    %{^pid => {_ref, name, _socket}} = process_map

    # recipient_names = Enum.flat_map(process_map, fn
    #   {^pid, {_, ^name, _}} -> []
    #   {_, {_, name, _}} -> [name]
    # end)
    # Logger.info("[#{name}] -> #{inspect(recipient_names)} #{inspect(message)}")
    Logger.info("[#{name}] #{inspect(message)}")

    payload = "[#{name}] #{message}"

    Enum.each(process_map, fn
      {^pid, _} ->
        :ok

      {_pid, {_ref, _name, socket}} ->
        send_message(socket, payload)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:DOWN, ref, :process, pid, _info},
        %{
          process_map: process_map,
          name_set: name_set
        } = state
      ) do
    %{^pid => {^ref, name, _socket}} = process_map
    process_map = Map.delete(process_map, pid)
    name_set = MapSet.delete(name_set, name)

    Logger.info("#{name} left")

    process_map
    |> Map.values()
    |> Enum.each(fn {_ref, _member_name, socket} ->
      notify_user_leaving(socket, name)
    end)

    state = %{state | process_map: process_map, name_set: name_set}

    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.error(
      "Room crashed with reason=#{inspect(reason)}: #{inspect(state)}"
    )

    :ok
  end

  defp notify_user_leaving(socket, name),
    do: :gen_tcp.send(socket, "* #{name} left\n")

  defp notify_user_joining(socket, name),
    do: :gen_tcp.send(socket, "* #{name} joined\n")

  defp inform_about_current_members(socket, members) do
    response = Enum.join(members, ", ")
    :gen_tcp.send(socket, "* current members: #{response}\n")
  end

  defp send_message(socket, message), do: :gen_tcp.send(socket, message)
end
