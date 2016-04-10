defmodule NXRedirect.Child do
  @moduledoc """
  Provides child implementation.
  """

  alias NXRedirect.DNSHeader, as: DNSHeader
  require Logger

  def start(client, primary, fallback) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true, reuseaddr: true])
    serve(client, primary, fallback, socket, %{})
    :ok = :gen_udp.close(socket)
    Logger.info "#{inspect self()} exiting…"
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
    after 5_000 -> nil
    end
    IO.puts (inspect buffer)
    if buffer != nil, do: serve(client, primary, fallback, dns_socket, buffer)
  end

  defp id(packet) do
    DNSHeader.header(packet).id
  end

  defp nxdomain?(packet) do
    DNSHeader.header(packet).rcode == << 3 :: size(4) >>
  end
end
