import Config

config :protohackers,
  problem: System.get_env("PROBLEM", "echo_server"),
  port: System.get_env("PORT", "4011") |> String.to_integer()
