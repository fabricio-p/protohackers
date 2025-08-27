defmodule Protohackers.PrimeTime do
  use Protohackers.TcpServer.Handler

  @prime_numbers :code.priv_dir(:protohackers)
                 |> Path.join("primes.txt")
                 |> File.stream!()
                 |> Enum.map(&String.trim/1)
                 |> Enum.map(&String.to_integer/1)

  @impl true
  def init(_socket), do: {:ok, nil}

  @impl true
  def handle_data(data, socket, state) do
    state
    |> case do
      nil -> :json.decode_start(data, {%{}, 0}, decoders())
      {:continue, cont} -> :json.decode_continue(data, cont)
    end
    |> case do
      {:continue, cont} ->
        if :binary.at(data, byte_size(data) - 1) == ?\n do
          close(socket)
        else
          {:ok, {:continue, cont}}
        end

      {%{method: :is_prime, number: number}, nil, ""} ->
        respond(socket, prime?(number))

      _ ->
        close(socket)
    end
  catch
    :error, _ -> close(socket)
  end

  defp respond(socket, prime?) do
    :gen_tcp.send(socket, ~s|{"method":"isPrime","prime":#{prime?}}\n|)
    {:ok, nil}
  end

  defp close(socket) do
    :gen_tcp.send(socket, "{}\n")
    :close
  end

  # to sanitize the data received
  defp decoders,
    do: %{
      object_start: fn {object, n} -> {object, n + 1} end,
      object_push: fn
        "number", number, {%{} = object, 1} ->
          {Map.put(object, :number, number), 1}

        "method", "isPrime", {%{} = object, 1} ->
          {Map.put(object, :method, :is_prime), 1}

        _key, _value, acc ->
          acc
      end,
      object_finish: fn
        {object, 1}, _acc -> {object, nil}
        {object, m}, {object, n} when m == n + 1 -> {object, {object, n}}
      end
    }

  defp prime?(number) when is_float(number), do: false
  defp prime?(number) when is_integer(number) and number <= 0, do: false
  defp prime?(1), do: false

  defp prime?(number) when is_integer(number) do
    max_prime = number |> :math.sqrt() |> ceil()
    prime?(number, prime_numbers(), max_prime)
  end

  defp prime?(_), do: :invalid

  defp prime?(number, [number | _rest], _max_prime), do: true

  defp prime?(_number, [prime | _rest], max_prime) when prime > max_prime,
    do: true

  defp prime?(number, [prime | rest], max_prime) do
    if rem(number, prime) == 0 do
      false
    else
      prime?(number, rest, max_prime)
    end
  end

  defp prime?(_number, [], _max_prime), do: true

  defp prime_numbers, do: @prime_numbers
end
