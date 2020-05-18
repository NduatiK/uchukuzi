defmodule UchukuziInterfaceWeb.CustomerSocket.BusChannel do
  use UchukuziInterfaceWeb, :channel

  @moduledoc """
  A channel through which to update bus information on the
  front-end in realtime
  """

  defp authorized?(socket, route_id) do
    Enum.member?(socket.assigns[:allowed_routes], route_id)
  end

  def join("bus_location:" <> route_id, _payload, socket) do
    if authorized?(socket, String.to_integer(route_id)) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def send_bus_location(route_id, last_seen_report) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "bus_location:" <> Integer.to_string(route_id),
      "update",
      last_seen_report
    )
  end
end
