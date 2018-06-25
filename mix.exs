defmodule NXRedirect.Mixfile do
  use Mix.Project

  def project do
    [app: :nxredirect,
     version: "1.0.0",
     elixir: "~> 1.6",
     description: description(),
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     escript: escript(),
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger],
     mod: {NXRedirect, []}]
  end

  def escript do
    [main_module: NXRedirect,
     app: nil]
  end

  # Dependencies can be Hex packages:
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:credo, ">= 0.0.0", only: [:dev, :test]},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test]}
    ]
  end

  defp description do
    """
    NXRedirect acts as a DNS Proxy which redirects NXDomain responses from
    a primary DNS server to a fallback. It is primary used to create
    split-view architecture where the primary server is internal and
    the fallback is public.
    """
  end

  defp package do
     [
       maintainers: ["Samuel BERNARD"],
       licenses: ["Apache 2.0"],
       links: %{
         "sources" => "https://gitlab.com/samuel.bernard/nxredirect",
         "issues" => "https://gitlab.com/samuel.bernard/nxredirect/issues"
       }
     ]
  end
end
