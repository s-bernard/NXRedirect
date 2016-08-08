defmodule NXRedirect do
  @moduledoc """
  Base module of NXRedirect
  """

  use Application
  require Record
  require Logger
  alias NXRedirect.Parent, as: Parent

  Record.defrecord :hostent,
    Record.extract(:hostent, from_lib: "kernel/include/inet.hrl")

  def main(args) do
    {parsed, _, _} = OptionParser.parse(args)
    add_config(parsed)
    Application.ensure_all_started(:nxredirect)
    :timer.sleep(:infinity)
  end

  def add_config([]), do: :ok

  def add_config([{key, value} | tail]) do
    Application.put_env(:nxredirect, key, value, persistent: true)
    add_config(tail)
  end

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec
    port = get_port()
    addresses = get_addresses()
    children = [
      supervisor(Task.Supervisor, [[name: NXRedirect.TaskSupervisor]]),
      worker(Task, [
        Parent, :start, [port, addresses]
      ])
    ]
    opts = [strategy: :one_for_one, name: NXRedirect.Supervisor]
    Logger.info "Starting NXRedirect application!"
    Logger.info printable_config(addresses, port)
    Supervisor.start_link(children, opts)
  end

  defp get_addresses do
    primary = get_primary()
    fallback = get_fallback()
    addresses = Map.new()
    addresses = Map.put(addresses, :primary, primary)
    addresses = Map.put(addresses, primary, :primary)
    addresses = Map.put(addresses, :fallback, fallback)
    Map.put(addresses, fallback, :fallback)
  end

  defp get_primary do
    parse_host(Application.get_env(:nxredirect, :primary))
  end

  defp get_fallback do
    parse_host(Application.get_env(:nxredirect, :fallback))
  end

  defp parse_host(host_port) do
    host_port = if is_binary(host_port) do
      [host, port] = String.split(host_port, ":")
      {to_char_list(host), String.to_integer(port)}
    else
      host_port
    end
    {:ok, addr} = :inet.parse_address(elem(host_port, 0))
    {addr, elem(host_port, 1)}
  end

  defp get_port do
    port = Application.get_env(:nxredirect, :port)
    if is_binary(port), do: String.to_integer(port), else: port
  end

  defp printable_config(addresses, port) do
    "Configuration:
    - port: #{port}
    - primary: #{printable_address(Map.get(addresses, :primary))}
    - fallback: #{printable_address(Map.get(addresses, :fallback))}"
  end

  defp printable_address(address) do
    {ip, port} = address
    "#{:inet.ntoa(ip)}:#{port}"
  end
end
