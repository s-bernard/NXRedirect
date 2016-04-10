defmodule NXRedirect do
  @moduledoc """
  Base module of NXRedirect
  """

  alias NXRedirect.Dns.Header, as: Header
  use Application
  require Record
  require Logger

  Record.defrecord :hostent,
    Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec
    Logger.info "Start application!"

    children = [
      supervisor(Task.Supervisor, [[name: NXRedirect.TaskSupervisor]]),
      worker(Task, [
        NXRedirect, :accept, [get_port(), get_primary(), get_fallback()]
      ])
    ]

    opts = [strategy: :one_for_one, name: NXRedirect.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port, primary, fallback) do
    {:ok, _socket} = :gen_udp.open(
      port,
      [:binary, active: true, reuseaddr: true]
    )
    Logger.info "Test in"
    recv_main(primary, fallback, %{}, %{})
  end

  defp get_primary do
    parse_host(Application.get_env(:nxredirect, :primary))
  end

  defp get_fallback do
    parse_host(Application.get_env(:nxredirect, :fallback))
  end

  defp parse_host(host_port) do
    {:ok, addr} = :inet.parse_address(elem(host_port, 0))
    {addr, elem(host_port, 1)}
  end

  defp get_port do
    Application.get_env(:nxredirect, :port)
  end

  defp recv_main(primary, fallback, clients, refs) do
    {clients, refs} = receive do
      {:udp, socket, addr, port, packet} ->
        client = {socket, addr, port}
        Logger.info "MAIN: Get #{inspect packet} from #{inspect addr}:#{port}"
        {pid, clients, refs} = case Map.fetch(clients, client) do
          {:ok, pid} -> {pid, clients, refs}
          :error ->
            pid = start_child(client, primary, fallback)
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
    recv_main(primary, fallback, clients, refs)
  end

  defp start_child(client, primary, fallback) do
    {:ok, pid} = Task.Supervisor.start_child(
      NXRedirect.TaskSupervisor,
      fn -> begin(client, primary, fallback) end
    )
    Logger.info "Started child #{inspect pid} to handle #{inspect client}"
    pid
  end

  defp begin(client, primary, fallback) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true, reuseaddr: true])
    serve(client, primary, fallback, socket, %{})
  end

  defp serve(client, primary, fallback, dns_socket, buffer) do
    {socket, addr, port} = client
    {prim_addr, prim_port} = primary
    {fall_addr, fall_port} = fallback
    buffer = receive do
      {:udp, ^dns_socket, ^prim_addr, ^prim_port, packet} ->
        if nxdomain?(packet) do
          status = Map.get(buffer, id(packet))
          case status do
            :sent -> Map.put(buffer, id(packet), :nxdomain)
            {:fallback, msg} ->
              :ok = :gen_udp.send(socket, addr, port, msg)
              Logger.info "#{inspect self()} - sent back fallback [2]"
              Map.delete(buffer, id(packet))
          end
        else
          :ok = :gen_udp.send(socket, addr, port, packet)
          Logger.info "#{inspect self()} - sent back primary"
          Map.delete(buffer, id(packet))
        end
      {:udp, ^dns_socket, ^fall_addr, ^fall_port, packet} ->
        status = Map.get(buffer, id(packet))
        case status do
          nil -> buffer
          :sent -> Map.put(buffer, id(packet), {:fallback, packet})
          :nxdomain ->
            :ok = :gen_udp.send(socket, addr, port, packet)
            Logger.info "#{inspect self()} - sent back fallback [1]"
            Map.delete(buffer, id(packet))
        end
      msg ->
        :ok = :gen_udp.send(dns_socket, prim_addr, prim_port, msg)
        :ok = :gen_udp.send(dns_socket, fall_addr, fall_port, msg)
        Logger.info "#{inspect self()} received #{inspect msg} & sent to DNSs"
        Map.put(buffer, id(msg), :sent)
    after 5_000 ->
      :ok = :gen_udp.close(dns_socket)
      Logger.info "#{inspect self()} exiting…"
      nil
    end
    IO.puts (inspect buffer)
    if buffer != nil, do: serve(client, primary, fallback, dns_socket, buffer)
  end

  defp id(packet) do
    Header.header(packet).id
  end

  defp nxdomain?(packet) do
    Header.header(packet).rcode == << 3 :: size(4) >>
  end
end

defmodule NXRedirect.Dns.Header do
  @moduledoc """
  Provide the "header" function to parse the header of a DNS message.
  """

  defstruct id:      <<>>,
            qr:      <<>>,
            opcode:  <<>>,
            aa:      <<>>,
            tc:      <<>>,
            rd:      <<>>,
            ra:      <<>>,
            z:       <<>>,
            rcode:   <<>>,
            qdcnt:   <<>>,
            ancnt:   <<>>,
            nscnt:   <<>>,
            arcnt:   <<>>

  @doc """
  Parse the header of a DNS message
  """
  def header(packet) do
    <<
      id        :: bytes - size(2),
      qr        :: bits - size(1),
      opcode    :: bits - size(4),
      aa        :: bits - size(1),
      tc        :: bits - size(1),
      rd        :: bits - size(1),
      ra        :: bits - size(1),
      z         :: bits - size(3),
      rcode     :: bits - size(4),
      qdcnt     :: unsigned - integer - size(16),
      ancnt     :: unsigned - integer - size(16),
      nscnt     :: unsigned - integer - size(16),
      arcnt     :: unsigned - integer - size(16),
      _payload  :: binary
    >> = packet
    %NXRedirect.Dns.Header{
      id:     id,
      qr:     qr,
      opcode: opcode,
      aa:     aa,
      tc:     tc,
      rd:     rd,
      ra:     ra,
      z:      z,
      rcode:  rcode,
      qdcnt:  qdcnt,
      ancnt:  ancnt,
      nscnt:  nscnt,
      arcnt:  arcnt
    }
  end
end
