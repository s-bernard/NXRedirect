defmodule NXRedirect.Parent do
  @moduledoc """
  Base module of NXRedirect
  """

  require Logger
  alias NXRedirect.Child, as: Child

  @doc """
  Starts accepting connections on the given `port`.
  """
  def start(port, primary, fallback) do
    {:ok, _socket} = :gen_udp.open(
      port,
      [:binary, active: true, reuseaddr: true]
    )
    recv_main(primary, fallback, %{}, %{})
  end

  defp recv_main(primary, fallback, clients, refs) do
    {clients, refs} = receive do
      {:udp, socket, addr, port, packet} ->
        client = {socket, addr, port}
        Logger.info "MAIN: Get #{inspect packet} from #{inspect addr}:#{port}"
        {pid, clients, refs} = case Map.fetch(clients, client) do
          {:ok, pid} -> {pid, clients, refs}
          :error ->
            pid = start_child(:udp, client, primary, fallback)
            clients = Map.put(clients, client, pid)
            refs = Map.put(refs, Process.monitor(pid), client)
            {pid, clients, refs}
        end
        send(pid, {:udp, socket, addr, port, packet})
        {clients, refs}
      {:DOWN, ref, :process, pid, _} ->
        {client, refs} = Map.pop(refs, ref)
        {^pid, clients} = Map.pop(clients, client)
        Logger.info "MAIN: Drop #{inspect client}:#{inspect pid}"
        {clients, refs}
      msg ->
        Logger.info "MAIN: Ignoring #{inspect msg}"
        {clients, refs}
    end
    recv_main(primary, fallback, clients, refs)
  end

  defp start_child(protocol, client, primary, fallback) do
    {:ok, pid} = Task.Supervisor.start_child(
      NXRedirect.TaskSupervisor,
      fn -> Child.start(protocol, client, primary, fallback) end
    )
    Logger.info "Started child #{inspect pid} to handle #{inspect client}"
    pid
  end
end
