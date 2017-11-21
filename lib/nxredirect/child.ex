defmodule NXRedirect.Child do
  @moduledoc """
  Provides child implementation.
  """

  alias NXRedirect.DNSHeader, as: DNSHeader
  require Logger

  def start(:tcp, socket, addresses) do
    me = self()
    pid = spawn_link(fn() -> start_main(:tcp, me, addresses) end)
    Process.flag(:trap_exit, true)
    :inet.setopts(socket, [active: :once])
    diplomat(socket, pid, {:client, :tcp}, %{})
  end

  def start(:udp, client_socket, addresses) do
    options = [:binary, active: true, reuseaddr: true]
    {:ok, socket} = :gen_udp.open(0, options)
    me = self()
    pid = spawn_link(fn() -> start_main(socket, me, addresses) end)
    dest = Map.fetch!(addresses, :client)
    Process.flag(:trap_exit, true)
    diplomat(client_socket, pid, {:client, dest}, addresses)
  end

  defp start_main(socket, client_pid, addresses) do
    main_pid = self()
    launch = fn(client) ->
      spawn_link(fn() ->
        Process.flag(:trap_exit, true)
        dest = Map.fetch!(addresses, client)
        diplomat(socket, main_pid, {client, dest}, %{})
      end)
    end
    [primary_pid, fallback_pid] = Enum.map([:primary, :fallback], launch)
    main(client_pid, primary_pid, fallback_pid, %{})
  end

  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  defp main(client, primary, fallback, state) do
    state = receive do
      {:client, message} ->
        Logger.debug fn ->
          "#{inspect self()}: forward #{inspect id(message)}"
        end
        send(primary, {self(), message})
        send(fallback, {self(), message})
        Map.put(state, id(message), :forwarded)
      {:primary, message} ->
        Logger.debug fn ->
          "#{inspect self()}: received reply from primary"
        end
        if nxdomain?(message) do
          status = Map.get(state, id(message))
          case status do
            :forwarded -> Map.put(state, id(message), :nxdomain)
            {:fallback, fallback_message} ->
              Logger.debug fn ->
                "#{inspect self()}: sent back fallback [1]"
              end
              send(client, {self(), fallback_message})
              Map.delete(state, id(message))
            _ -> state # ignore message
          end
        else
          Logger.debug fn ->
            "#{inspect self()}: sent back primary"
          end
          send(client, {self(), message})
          Map.delete(state, id(message))
        end
      {:fallback, message} ->
        Logger.debug fn ->
          "#{inspect self()}: received reply from fallback"
        end
        status = Map.get(state, id(message))
        case status do
          :forwarded ->
            Map.put(state, id(message), {:fallback, message})
          :nxdomain ->
            Logger.debug fn ->
              "#{inspect self()}: sent back fallback [2]"
            end
            send(client, {self(), message})
            Map.delete(state, id(message))
          _ -> state
        end
      msg ->
        Logger.warn("#{inspect self()}(main): discarding #{inspect msg}")
        state
    after 5_000 ->
      Logger.debug fn ->
        "#{inspect self()}(main): timeout…"
      end
      exit(:timeout)
    end
    main(client, primary, fallback, state)
  end

  defp diplomat(:tcp, pid, {client, {addr, port}}, addresses) do
    Process.flag(:trap_exit, true)
    options = [:binary, packet: 2, active: :once, reuseaddr: true]
    {:ok, socket} = :gen_tcp.connect(addr, port, options)
    diplomat(socket, pid, {client, :tcp}, addresses)
  end

  # credo:disable-for-next-line Credo.Check.Refactor.ABCSize
  defp diplomat(socket, pid, {client, dest}, addresses) do
    receive do
      {^pid, message} -> netsend(socket, message, dest)
      {:tcp, ^socket, message} ->
        send(pid, {client, message})
        :inet.setopts(socket, [active: :once])
      {:tcp_closed, ^socket} -> exit(:normal)
      {:udp, _, addr, port, message} ->
        from = Map.fetch!(addresses, {addr, port})
        send(pid, {from, message})
      {:EXIT, ^pid, _} -> exiting(socket, dest)
      msg ->
        Logger.warn("#{inspect self()}(#{client}): discarding #{inspect msg}")
    end
    diplomat(socket, pid, {client, dest}, addresses)
  end

  defp exiting(socket, :tcp) do
    :gen_tcp.close(socket)
    exit(:normal)
  end

  defp exiting(_socket, _) do
    exit(:normal)
  end

  defp netsend(socket, message, :tcp) do
    :ok = :gen_tcp.send(socket, message)
  end

  defp netsend(socket, message, {addr, port}) do
    :ok = :gen_udp.send(socket, addr, port, message)
  end

  defp id(packet) do
    DNSHeader.header(packet).id
  end

  defp nxdomain?(packet) do
    DNSHeader.header(packet).rcode == << 3 :: size(4) >>
  end
end
