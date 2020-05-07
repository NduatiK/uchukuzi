defmodule UchukuziInterfaceWeb.RouteChannel do
  use UchukuziInterfaceWeb, :channel

  @moduledoc """
  A channel through which to update bus information on the
  front-end in realtime
  """

  # alias Uchukuzi.School
  # alias Uchukuzi.School.BusesSupervisor

  defp authorized?(socket, route_id) do
    Enum.member?(socket.assigns[:allowed_routes], route_id)
  end

  def join("routes:" <> route_id, _payload, socket) do
    if authorized?(socket, String.to_integer(route_id)) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def send_to_channel(route_id, type, data) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "routes:" <> Integer.to_string(route_id),
      type,
      data
    )
  end
end
