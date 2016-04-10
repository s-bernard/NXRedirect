defmodule NXRedirect.Mixfile do
  use Mix.Project

  def project do
    [app: :nxredirect,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger],
     mod: {NXRedirect, []}]
  end

  # Dependencies can be Hex packages:
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:credo, "~> 0.3", only: [:dev, :test]},
      {:dogma, "~> 0.1", only: [:dev, :test]},
      {:dialyxir, "~> 0.3", only: [:dev, :test]}
    ]
  end
end
