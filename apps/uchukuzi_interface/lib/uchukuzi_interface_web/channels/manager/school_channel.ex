defmodule UchukuziInterfaceWeb.ManagerSocket.SchoolChannel do
  use UchukuziInterfaceWeb, :channel

  @moduledoc """
  A channel through which to update bus information on the
  front-end in realtime
  """

  alias Uchukuzi.{School, Tracking}
  # alias Uchukuzi.School.BusesSupervisor
  defp authorized?(socket, school_id) do
    socket.assigns[:school_id] == school_id
  end

  def join("school:" <> school_id, _payload, socket) do
    if authorized?(socket, String.to_integer(school_id)) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("bus_locations", _payload, socket) do
    reply = %{
      bus_data:
        socket.assigns[:school_id]
        |> School.buses_for()
        |> Tracking.add_location_to_buses()
    }

    {:reply, {:ok, reply}, socket}
  end

  def send_notification(school_id, update) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "school:" <> Integer.to_string(school_id),
      "notification",
      update
    )
  end

  def send_bus_event(school_id, %{
        event: "left_school",
        number_plate: number_plate,
        students_onboard: students_onboard,
        bus_id: bus_id
      }) do
    send_notification(school_id, %{
      time: DateTime.utc_now(),
      title: "Bus Left School",
      content:
        "Bus #{number_plate} has left the school with #{Enum.count(students_onboard)} students onboard",
      redirectUrl: "/#/fleet/#{bus_id}"
    })
  end

  def send_bus_event(school_id, %{
        event: "arrived_at_school",
        number_plate: number_plate,
        students_onboard: students_onboard,
        bus_id: bus_id
      }) do
    send_notification(school_id, %{
      time: DateTime.utc_now(),
      title: "Bus Arrived",
      content:
        "Bus #{number_plate} has arrived at school with #{Enum.count(students_onboard)} students onboard",
      redirectUrl: "/#/fleet/#{bus_id}"
    })
  end

  def send_bus_event(_, _) do
  end
end
