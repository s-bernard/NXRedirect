defmodule NXRedirect do
  use Application
  require Logger

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec
    children = [
      supervisor(Task.Supervisor, [[name: NXRedirect.TaskSupervisor]]),
      worker(Task, [NXRedirect, :accept, [port(), primary(), fallback()]])
    ]

    opts = [strategy: :one_for_one, name: NXRedirect.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port, primary, fallback) do
    {:ok, socket} = :gen_udp.open(
      port,
      [:binary, active: true, reuseaddr: true]
    )
    recv_main(primary, %{}, %{})
  end

  defp primary() do
    Application.get_env(:nxredirect, :primary)
  end

  defp fallback() do
    Application.get_env(:nxredirect, :fallback)
  end

  defp port() do
    Application.get_env(:nxredirect, :port)
  end

  defp recv_main(primary, clients, refs) do
    {clients, refs} = receive do
      {:udp, socket, addr, port, packet} ->
        client = {socket, addr, port}
        Logger.info "MAIN: Get #{inspect packet} from #{inspect addr}:#{port}"
        {pid, clients, refs} = case Map.fetch(clients, client) do
          {:ok, pid} -> {pid, clients, refs}
          :error ->
            pid = start_child(client, primary)
            clients = Map.put(clients, client, pid)
            refs = Map.put(refs, Process.monitor(pid), client)
            {pid, clients, refs}
        end
        send pid, packet
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
    recv_main primary, clients, refs
  end

  defp start_child(client, primary) do
    {:ok, pid} = Task.Supervisor.start_child(
      NXRedirect.TaskSupervisor,
      fn -> begin(client, primary) end
    )
    Logger.info "Started child #{inspect pid} to handle #{inspect client}"
    pid
  end

  defp begin(client, primary) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true, reuseaddr: true])
    serve(client, primary, socket)
  end

  defp serve(client, primary, dns_socket) do
    {socket, addr, port} = client
    {dns_addr, dns_port} = primary
    loop? = receive do
      {:udp, ^dns_socket, _dns_addr, _dns_port, packet} ->
        Logger.info "#{inspect self()} received #{inspect packet} from dns"
        :ok = :gen_udp.send(socket, addr, port, packet)
        Logger.info "#{inspect self()} #{inspect packet} sent back to client"
        true
      msg ->
        Logger.info "#{inspect self()} received #{inspect msg}"
        :ok = :gen_udp.send(dns_socket, dns_addr, dns_port, msg)
        Logger.info "#{inspect self()} #{inspect msg} sent to DNS"
        true
    after 5_000 ->
      :ok = :gen_udp.close(dns_socket)
      Logger.info "#{inspect self()} exiting…"
      false
    end
    if loop?, do: serve(client, primary, dns_socket)
  end
end
