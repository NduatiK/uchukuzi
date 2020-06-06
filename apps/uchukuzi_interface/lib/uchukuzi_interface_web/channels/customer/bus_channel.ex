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

  def send_bus_event(route_id, event) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "bus_location:" <> Integer.to_string(route_id),
      "event",
      event
    )
  end

  intercept ["event", "update"]

  defp authorized_to_receive?(socket, msg) do
    case socket.assigns.student_ids
         |> Enum.filter(fn id ->
           Enum.member?(msg.students_onboard, id)
         end) do
      [] -> nil
      students -> students
    end
  end

  def handle_out(event, msg, socket) do
    cond do
      students = authorized_to_receive?(socket, msg) ->
        push(socket, event, Map.put(msg, :students_onboard, students))
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end
end
