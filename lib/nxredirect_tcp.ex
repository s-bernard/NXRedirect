defmodule NXRedirectTcp do
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
    socket = listen(port)
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket, primary, fallback)
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

  defp listen(port) do
    {:ok, socket} = :gen_tcp.listen(port,
      [:binary, packet: :line, active: false, reuseaddr: true])
    socket
  end

  defp connect({server, port}) do
    {:ok, socket} = :gen_tcp.connect(server, port,
      [:binary, packet: :line, active: false])
    socket
  end

  defp loop_acceptor(socket, primary, fallback) do
    {:ok, client} = :gen_tcp.accept(socket)
     Logger.info "Receive connection from #{inspect client}"
    {:ok, pid} = Task.Supervisor.start_child(
      NXRedirect.TaskSupervisor,
      fn -> serve(client, primary, fallback) end
    )
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket, primary, fallback)
  end

  defp serve(socket, primary, fallback) do
    socket |> read_line() |> write_line(primary, fallback)
    serve(socket, primary, fallback)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line(line, {primary, p_port}, {fallback, f_port}) do
    write_and_read(line, primary, p_port)
    Logger.info "Redirect to #{inspect primary}"
  end

  defp write_and_read(line, server, port) do
    {:ok, socket} = :gen_tcp.connect(server, port,
      [:binary, packet: :line, active: false]
    )
    :gen_tcp.send(socket, line)
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end
end
