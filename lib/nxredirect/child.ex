defmodule NXRedirect.Child do
  @moduledoc """
  Provides child implementation.
  """

  alias NXRedirect.DNSHeader, as: DNSHeader
  require Logger

  def start(:udp, client, primary, fallback) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true, reuseaddr: true])
    me = self
    Process.flag(:trap_exit, true)
    main_pid = spawn_link(fn() -> start_main(socket, me, primary, fallback) end)
    diplomat(client, primary, fallback, {socket, main_pid})
  end

  defp start_main(socket, client_pid, primary, fallback) do
    main_pid = self
    primary_pid = spawn_link(fn() -> diplomat(socket, primary, main_pid) end)
    fallback_pid = spawn_link(fn() -> diplomat(socket, fallback, main_pid) end)
    main(client_pid, primary_pid, fallback_pid, %{})
  end

  defp main(client, primary, fallback, state) do
    state = receive do
      {:client, message} ->
        Logger.debug "#{inspect self}: forward #{inspect id(message)}"
        send(primary, {self, message})
        send(fallback, {self, message})
        Map.put(state, id(message), :forwarded)
      {:primary, message} ->
        if nxdomain?(message) do
          status = Map.get(state, id(message))
          case status do
            :forwarded -> Map.put(state, id(message), :nxdomain)
            {:fallback, fallback_message} ->
              Logger.debug "#{inspect self()}: sent back fallback [1]"
              send(client, {self, fallback_message})
              Map.delete(state, id(message))
            _ -> state # ignore message
          end
        else
          Logger.debug "#{inspect self()}: sent back primary"
          send(client, {self, message})
          Map.delete(state, id(message))
        end
      {:fallback, message} ->
        status = Map.get(state, id(message))
        case status do
          :forwarded -> Map.put(state, id(message), {:fallback, message})
          :nxdomain ->
            Logger.debug "#{inspect self()}: sent back fallback [2]"
            send(client, {self, message})
            Map.delete(state, id(message))
          _ -> state
        end
      msg ->
        Logger.warn("#{inspect self()}: discarding #{inspect msg}")
        state
    after 5_000 -> exit(:timeout)
    end
    main(client, primary, fallback, state)
  end

  defp diplomat(socket, {addr, port}, pid) do
    receive do
      {^pid, message} -> :gen_udp.send(socket, addr, port, message)
      msg -> Logger.warn("#{inspect self()}: discarding #{inspect msg}")
    end
    diplomat(socket, {addr, port}, pid)
  end

  defp diplomat(client, primary, fallback, main_infos) do
    {client_socket, client_addr, client_port} = client
    {prim_addr, prim_port} = primary
    {fall_addr, fall_port} = fallback
    {socket, pid} = main_infos
    receive do
      {:udp, ^client_socket, ^client_addr, ^client_port, message} ->
        send(pid, {:client, message})
      {:udp, ^socket, ^prim_addr, ^prim_port, message} ->
        send(pid, {:primary, message})
      {:udp, ^socket, ^fall_addr, ^fall_port, message} ->
        send(pid, {:fallback, message})
      {^pid, message} ->
        :ok = :gen_udp.send(client_socket, client_addr, client_port, message)
      {:EXIT, ^pid, _} -> exiting(socket)
      msg -> Logger.warn("#{inspect self()}: discarding #{inspect msg}")
    end
    diplomat(client, primary, fallback, main_infos)
  end

  defp exiting(socket) do
    :ok = :gen_udp.close(socket)
    Logger.debug "#{inspect self()} exiting…"
    exit(:normal)
  end

  defp id(packet) do
    DNSHeader.header(packet).id
  end

  defp nxdomain?(packet) do
    DNSHeader.header(packet).rcode == << 3 :: size(4) >>
  end
end
