defmodule NXRedirect.Parent do
  @moduledoc """
  Base module of NXRedirect
  """

  require Logger
  alias NXRedirect.Child, as: Child

  @doc """
  Starts accepting connections on the given `port`.
  """
  def start(port, addresses) do
    pid = spawn_link(fn() -> accept(port, addresses) end)
    Logger.debug "Launched #{inspect pid} to handle TCP requests"
    {:ok, _socket} = :gen_udp.open(
      port,
      [:binary, active: true, reuseaddr: true]
    )
    recv_udp(addresses, %{}, %{})
  end

  defp accept(port, addresses) do
    options = [:binary, packet: 2, active: false, reuseaddr: true]
    {:ok, socket} = :gen_tcp.listen(port, options)
    Logger.debug "Accepting connections on port #{port}"
    loop_acceptor(socket, addresses)
  end

  defp loop_acceptor(socket, addresses) do
    {:ok, client_socket} = :gen_tcp.accept(socket)
    {:ok, {addr, port}} = :inet.peername(client_socket)
    Logger.debug "Receive connection from #{inspect {addr, port}}"
    pid = start_child(:tcp, {client_socket, addr, port}, addresses)
    :ok = :gen_tcp.controlling_process(client_socket, pid)
    loop_acceptor(socket, addresses)
  end

  defp recv_udp(addresses, clients, refs) do
    {clients, refs} = receive do
      {:udp, socket, addr, port, packet} ->
        client = {socket, addr, port}
        Logger.debug "MAIN: Get #{inspect packet} from #{inspect addr}:#{port}"
        client_pid(addresses, refs, clients, {client, packet})
      {:DOWN, ref, :process, pid, _} ->
        drop_client(refs, clients, ref, pid)
      msg ->
        Logger.warn "MAIN: Ignoring #{inspect msg}"
        {clients, refs}
    end
    recv_udp(addresses, clients, refs)
  end

  defp drop_client(refs, clients, ref, pid) do
    {client, refs} = Map.pop(refs, ref)
    {^pid, clients} = Map.pop(clients, client)
    Logger.debug "MAIN: Drop #{inspect client}:#{inspect pid}"
    {clients, refs}
  end

  defp client_pid(addresses, refs, clients, {client, packet}) do
    {socket, addr, port} = client
    {pid, clients, refs} = case Map.fetch(clients, client) do
      {:ok, pid} -> {pid, clients, refs}
      :error ->
        pid = start_child(:udp, client, addresses)
        clients = Map.put(clients, client, pid)
        refs = Map.put(refs, Process.monitor(pid), client)
        {pid, clients, refs}
    end
    send(pid, {:udp, socket, addr, port, packet})
    {clients, refs}
  end

  defp start_child(protocol, {socket, addr, port}, addresses) do
    addresses = Map.put(addresses, :client, {addr, port})
    addresses = Map.put(addresses, {addr, port}, :client)
    {:ok, pid} = Task.Supervisor.start_child(
      NXRedirect.TaskSupervisor,
      fn -> Child.start(protocol, socket, addresses) end
    )
    Logger.debug "Started #{inspect pid} to handle #{inspect {addr, port}}"
    pid
  end
end
