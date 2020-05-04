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

  # alias Phoenix.Socket.Broadcast

  # def handle_info(%Broadcast{topic: _, event: "prediction_update", payload: payload}, socket) do
  #   broadcast(socket, "prediction_update", payload.eta_sequence)

  #   {:noreply, socket}
  # end
  # alias Phoenix.Socket.Broadcast

  def handle_info(%{type: "prediction_update"} = e, socket) do

    broadcast(socket, "prediction_update", e.payload)

    {:noreply, socket}
  end



  # def handle_in("prediction_update", payload, socket) do
  #   IO.inspect(payload)


  #   {:noreply, socket}
  # end

  def send_to_channel(route_id, type, data) do
    Phoenix.PubSub.broadcast(
      Uchukuzi.PubSub,
      "routes:" <> Integer.to_string(route_id),
      %{type: type, payload: data}
    )
  end
end
