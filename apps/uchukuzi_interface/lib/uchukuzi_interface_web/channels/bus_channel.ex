defmodule UchukuziInterfaceWeb.BusChannel do
  use UchukuziInterfaceWeb, :channel

  @moduledoc """
  A channel through which to update bus information on the
  front-end in realtime
  """

  # alias Uchukuzi.School
  # alias Uchukuzi.School.BusesSupervisor

  def join("bus:" <> _bus_id, _payload, socket) do
    {:ok, socket}
  end

  def handle_in("hello", payload, socket) do
    # {:reply, {:ok, payload}, socket}
    # FlotillaAPI.RouteChannel.send_to_channel("routes:1", "update", %{
    #   route_id: 1,
    #   latitude: report_params["lat"],
    #   longitude: report_params["lng"],
    #   bearing: Enum.random(1..130),
    #   timestamp: time
    # })
    # push(socket, "said_hello", payload)
    broadcast!(socket, "said_hello", payload)
    {:noreply, socket}

    # payload = %{message: "We forced this error."}
    # {:reply, {:error, payload}, socket}
  end
end
