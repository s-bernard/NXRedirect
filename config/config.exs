# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

config :logger,
  utc_log: true,
  compile_time_purge_level: if Mix.env == :prod, do: :info, else: :debug

# primary and fallback addresses can also be formated in string:
# primary: "127.0.0.1:53",
# fallback: "8.8.8.8:53",
config :nxredirect,
  primary: {'127.0.0.1', 53},
  fallback: {'8.8.8.8', 53},
  port: 53053

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
