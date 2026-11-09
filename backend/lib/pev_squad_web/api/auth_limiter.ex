defmodule PevSquadWeb.API.AuthLimiter do
  @moduledoc "Bounded, node-local throttling for app authentication attempts."
  use GenServer
  import Plug.Conn
  alias PevSquadWeb.API.Errors

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(state), do: {:ok, state}

  def call(conn, _opts) do
    email =
      case conn.params["email"] do
        value when is_binary(value) ->
          value |> String.trim() |> String.downcase() |> :erlang.phash2()

        _ ->
          nil
      end

    keys = [{:ip, conn.remote_ip, 100}] ++ if(email, do: [{:email, email, 5}], else: [])

    if GenServer.call(__MODULE__, {:allow, keys}) do
      conn
    else
      conn |> put_resp_header("retry-after", "60") |> Errors.send_error(:rate_limited) |> halt()
    end
  end

  def handle_call({:allow, keys}, _from, state) do
    now = System.monotonic_time(:second)
    state = Map.reject(state, fn {_key, {_n, deadline}} -> deadline <= now end)

    allowed =
      map_size(state) < 10_000 and
        Enum.all?(keys, fn {kind, value, max} ->
          {n, _} = Map.get(state, {kind, value}, {0, now + 60})
          n < max
        end)

    state =
      if allowed do
        Enum.reduce(keys, state, fn {kind, value, _}, acc ->
          Map.update(acc, {kind, value}, {1, now + 60}, fn {n, deadline} -> {n + 1, deadline} end)
        end)
      else
        state
      end

    {:reply, allowed, state}
  end
end
