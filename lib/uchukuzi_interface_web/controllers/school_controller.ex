defmodule UchukuziInterfaceWeb.SchoolController do
  use UchukuziInterfaceWeb, :controller

  alias Uchukuzi.School
  action_fallback UchukuziInterfaceWeb.FallbackController

  def create_school(conn, %{"manager" => manager_params, "school" => school_params}) do
    with center <- %{
           longitude: school_params["geo"]["lon"],
           latitude: school_params["geo"]["lat"]
         },
         geofence <- %{
           radius: school_params["geo"]["radius"],
           center: center
         },
         school <- School.School.new(school_params["name"], geofence),
         {:ok, %{manager: manager, school: _school}} <-
           School.create_school(school, manager_params) do
      conn
      |> put_status(:created)
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("manager.json", manager: manager, token: AuthManager.sign(manager.id))
    end
  end

  def create_bus(conn, bus_params) do
    with {:ok, bus} <- School.create_bus(conn.assigns.manager.school_id, bus_params) do
      bus = Repo.preload(bus, :device)

      conn
      |> put_status(:created)
      |> render("bus.json", bus: bus)
    end
  end

  def list_buses(conn, _) do
    buses =
      for bus <- School.buses_for(conn.assigns.manager.school_id) do
        Repo.preload(bus, :device)
      end

    conn
    |> render("buses.json", buses: buses)
  end

  def get_bus(conn, %{"bus_id" => bus_id}) do
    with {bus_id, ""} <- Integer.parse(bus_id),
         {:ok, bus} <- School.bus_for(conn.assigns.manager.school_id, bus_id) do
      bus = Repo.preload(bus, :device)

      conn
      |> render("bus.json", bus: bus)
    else
      {_, _} ->
        conn
        |> resp(:bad_request, "Buses have an integer id")

      :error ->
        conn
        |> resp(:bad_request, "Buses have an integer id")
    end
  end

  def register_device(conn, %{"bus_id" => bus_id, "imei" => imei}) do
    with {:ok, bus} <- School.bus_for(conn.assigns.manager.school_id, bus_id),
         bus <- Repo.preload(bus, :device),
         nil <- Map.get(bus, :device),
         {:ok, _} <- School.register_device(bus, imei) do
      conn
      |> resp(:created, "")
    else
      %School.Device{} ->
        conn
        |> resp(:bad_request, %{errors: %{detail: %{imei: ["already registered to another bus"]}}})
    end
  end
end
