defmodule UchukuziInterfaceWeb.SchoolChannel do
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
end
