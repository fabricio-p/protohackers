defmodule Protohackers.MeansToAnEnd do
  use Protohackers.TcpServer.Handler

  require Logger

  def init(_socket) do
    prices_table = :ets.new(:prices, [:ordered_set, :private])
    {:ok, {"", prices_table}}
  end

  def handle_data(data, socket, {buffered, prices_table}) do
    data = <<buffered::binary, data::binary>>

    if byte_size(data) >= 9 do
      {messages, buffered} = parse_messages(data)
      message_chunks = Enum.chunk_by(messages, &match?({:query, _, _}, &1))

      Enum.each(message_chunks, fn
        [{:query, _, _} | _] = queries ->
          queries
          |> Enum.map(fn {:query, mintime, maxtime} -> {mintime, maxtime} end)
          |> Enum.map(&query(&1, prices_table))
          |> Enum.each(&respond_query(&1, socket))

        [{:insert, _, _} | _] = inserts ->
          inserts
          |> Enum.map(fn {:insert, timestamp, price} -> {timestamp, price} end)
          |> Enum.each(&handle_insert(&1, prices_table))
      end)

      {:ok, {buffered, prices_table}}
    else
      {:ok, {data, prices_table}}
    end
  end

  defp query({mintime, maxtime}, _prices_table)
       when mintime > maxtime,
       do: []

  defp query({mintime, maxtime}, prices_table) do
    match_spec = [
      {{:"$1", :"$2"},
       [
         {:>=, :"$1", mintime},
         {:"=<", :"$1", maxtime}
       ], [:"$2"]}
    ]

    :ets.select(prices_table, match_spec)
  end

  defp respond_query(prices, socket) do
    avg = average(prices)
    response = <<avg::integer-signed-size(32)-big>>
    :gen_tcp.send(socket, response)
  end

  defp average([]), do: 0
  defp average(prices), do: div(Enum.sum(prices), length(prices))

  defp handle_insert(pairs, prices_table) do
    true = :ets.insert(prices_table, pairs)
  end

  defp parse_messages(data) do
    {messages, buffered} = parse_messages(data, [])
    messages = Enum.reverse(messages)
    {messages, buffered}
  end

  defp parse_messages(<<raw::binary-size(9), rest::binary>>, acc) do
    message = parse_message(raw)
    parse_messages(rest, [message | acc])
  end

  defp parse_messages(buffered, acc), do: {acc, buffered}

  defp parse_message(
         <<?I, timestamp::integer-signed-size(32)-big,
           price::integer-signed-size(32)-big>>
       ),
       do: {:insert, timestamp, price}

  defp parse_message(
         <<?Q, mintime::integer-signed-size(32)-big,
           maxtime::integer-signed-size(32)-big>>
       ),
       do: {:query, mintime, maxtime}
end
