defmodule UchukuziInterfaceWeb.SchoolView do
  use UchukuziInterfaceWeb, :view
  use Uchukuzi.School.Model

  def render("buses.json", %{buses: buses}) do
    buses
    |> Enum.map(fn {bus, last_seen} -> %{bus: bus, last_seen: last_seen} end)
    |> render_many(__MODULE__, "bus.json")
  end

  def render("show.json", %{bus: bus}) do
    render_one(bus, __MODULE__, "bus.json", as: :bus)
  end

  def render("bus.json", %{school: params}), do: render("bus.json", params)

  def render("bus.json", %{bus: bus} = params) do
    render_bus(bus, Map.get(params, :last_seen), Map.get(bus, :performed_repairs))
  end

  def render_bus(bus, last_seen \\ nil, performed_repairs \\ nil) do
    %{
      id: bus.id,
      number_plate: bus.number_plate,
      vehicle_type: bus.vehicle_type,
      fuel_type: bus.fuel_type,
      stated_milage: bus.stated_milage,
      seats_available: bus.seats_available,
      device: render_device(bus.device),
      route: render_bus_route(Map.get(bus, :route)),
      # route: bus.route,
      last_seen: render_last_seen(last_seen),
      performed_repairs: render_performed_repairs(performed_repairs)
    }
  end

  def render("simple_routes.json", %{routes: routes}) do
    routes
    |> render_many(__MODULE__, "simple_route.json", as: :route)
  end

  def render("simple_route.json", %{route: route}) do
    %{
      id: route.id,
      name: route.name,
      path: route.path |> Enum.map(&render_location/1),
      bus_id:
        with bus = %Bus{} <- Map.get(route, :bus) do
          bus.id
        end
    }
  end

  def render("routes.json", %{routes: routes}) do
    routes
    |> render_many(__MODULE__, "route.json", as: :route)
  end

  def render("route.json", %{route: route}) do
    %{
      id: route.id,
      name: route.name,
      path: route.path |> Enum.map(&render_location/1),
      bus:
        with bus = %Bus{} <- Map.get(route, :bus) do
          %{id: bus.id, number_plate: bus.number_plate}
        end
    }
  end

  def render("fuel_reports.json", %{fuel_reports: fuel_reports}) do
    fuel_reports
    |> render_many(__MODULE__, "fuel_report.json", as: :fuel_report)
  end

  def render("fuel_report.json", %{fuel_report: fuel_report}) do
    IO.inspect(fuel_report)
    %{
      id: fuel_report.id,
      cost: fuel_report.cost,
      volume: fuel_report.volume,
      date: fuel_report.date,
      distance_travelled: fuel_report.distance_travelled
    }
  end

  def render_bus_route(nil), do: nil
  def render_bus_route(%Ecto.Association.NotLoaded{}), do: nil

  def render_bus_route(route) do
    %{id: route.id, name: route.name}
  end

  def render_last_seen(nil), do: nil

  def render_last_seen(report) do
    %{
      location: %{
        lng: report.location.lng,
        lat: report.location.lat
      },
      speed: Float.round(report.speed + 0.0, 1),
      bearing: Float.round(report.bearing + 0.0, 1),
      time: report.time
    }
  end

  def render_device(nil), do: nil
  def render_device(%Ecto.Association.NotLoaded{}), do: nil
  def render_device(device), do: device.imei

  def render_performed_repairs(nil), do: nil
  def render_performed_repairs(%Ecto.Association.NotLoaded{}), do: []

  def render_performed_repairs(performed_repairs) do
    Enum.map(performed_repairs, fn repair ->
      %{
        id: repair.id,
        part: repair.part,
        time: repair.inserted_at,
        cost: repair.cost,
        description: repair.description || ""
      }
    end)
  end

  def render_location(location) do
    %{
      lng: location.lng,
      lat: location.lat
    }
  end
end
