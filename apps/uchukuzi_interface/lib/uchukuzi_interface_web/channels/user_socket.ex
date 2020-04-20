defmodule UchukuziInterfaceWeb.UserSocket do
  use Phoenix.Socket

  # Any topics starting with bus go through BusChannel
  channel "bus:*", UchukuziInterfaceWeb.BusChannel

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
