defmodule UchukuziInterfaceWeb.ManagerSocket.TripChannel do
  use UchukuziInterfaceWeb, :channel
  alias Uchukuzi.{School, Tracking}

  def join("trip:" <> bus_id, _payload, socket) do
    with {:ok, bus} <- School.bus_for(socket.assigns[:school_id], bus_id) do
      {:ok, assign(socket, :bus, bus)}

      reply =
        bus
        |> Tracking.TripTracker.ongoing_trip()
        |> (fn trip -> UchukuziInterfaceWeb.TrackingView.render("trip.json", %{trip: trip}) end).()

      {:ok, reply, assign(socket, :bus, bus)}
    else
      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("ongoing_trip", _payload, socket) do
    reply = %{
      bus_data:
        socket.assigns[:bus]
        |> Tracking.TripTracker.ongoing_trip()
    }

    {:reply, {:ok, reply}, socket}
  end

  def send_trip_update(bus_id, %Tracking.StudentActivity{} = report) do
    send_update(bus_id, UchukuziInterfaceWeb.TrackingView.render_student_activity(report))
  end

  def send_trip_update(bus_id, %Uchukuzi.Common.Report{} = report) do
    send_update(bus_id, UchukuziInterfaceWeb.TrackingView.render_report(report))
  end

  def send_trip_update(bus_id, %Uchukuzi.Tracking.Trip{} = report) do
    send_update(bus_id, UchukuziInterfaceWeb.TrackingView.render_trip(report))
  end

  def send_trip_update(_, _), do: nil

  defp send_update(bus_id, update) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "trip:" <> Integer.to_string(bus_id),
      "update",
      update
    )
  end

  def send_trip_ended(bus_id) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "trip:" <> Integer.to_string(bus_id),
      "ended",
      %{}
    )
  end
end
