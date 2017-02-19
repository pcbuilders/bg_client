defmodule BigoClient do
  use Application

  def start(_type, _args) do
    if Mix.env === :prod do
      Task.start_link(fn -> BigoClient.Client.main() end)
    end
    Task.start_link(fn -> BigoClient.Client.loop() end)
  end
end
