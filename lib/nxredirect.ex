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
    {:ok, socket} = :gen_udp.open(port,
      [:binary, active: false, reuseaddr: true])
    loop(socket, primary)
  end

  defp loop(socket, {p_addr, p_port}) do
    {:ok, {addr, port, packet}} = :gen_udp.recv(socket, 0)
    Logger.info "Received packet from #{inspect addr}"
    :ok = :gen_udp.send(socket, p_addr, p_port, packet)
    Logger.info "Send packet to #{p_addr}:#{p_port}"
    {:ok, {addr, port, packet}} = :gen_udp.recv(socket, 0)
    Logger.info "Received packet from #{inspect addr}"
    :ok = :gen_udp.send(socket, addr, port, packet)
    Logger.info "Send packet to #{inspect addr}:#{port}"
    loop(socket, {p_addr, p_port})
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
end
