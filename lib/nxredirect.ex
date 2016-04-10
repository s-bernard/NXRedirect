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

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec
    children = [
      supervisor(Task.Supervisor, [[name: NXRedirect.TaskSupervisor]]),
      worker(Task, [
        Parent, :start, [get_port(), get_primary(), get_fallback()]
      ])
    ]
    opts = [strategy: :one_for_one, name: NXRedirect.Supervisor]
    Logger.info "Starting NXRedirect application!"
    Supervisor.start_link(children, opts)
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
end
