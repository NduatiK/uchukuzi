defmodule UchukuziInterfaceWeb.SchoolView do
  use UchukuziInterfaceWeb, :view
  use Uchukuzi.School.Model

  def render("school.json", %{school: school}) do
    %{
      "location" => %{
        "lat" => school.perimeter.center.lat,
        "lng" => school.perimeter.center.lng
      },
      "radius" => school.perimeter.radius,
      "name" => school.name
    }
  end

  def render("buses.json", %{buses: buses}) do
    buses
    |> Enum.map(fn {bus, last_seen} -> %{bus: bus, last_seen: last_seen} end)
    |> render_many(__MODULE__, "bus.json")
  end

  def render("bus.json", %{school: params}), do: render("bus.json", params)

  def render("bus.json", %{bus: bus} = params) do
    render_bus(bus, Map.get(params, :last_seen), Map.get(bus, :performed_repairs))
  end

  def render_bus(bus, last_seen \\ nil, performed_repairs \\ nil)

  def render_bus(nil, _, _) do
    nil
  end

  def render_bus(bus, last_seen, performed_repairs) do
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
      last_seen: UchukuziInterfaceWeb.TrackingView.render_report(last_seen),
      performed_repairs: render_performed_repairs(performed_repairs)
    }
  end

  def render("route_for_assistant.json", %{
        data: %{
          crew_member: crew_member,
          bus: bus,
          students: students,
          route: route
        }
      }) do
    %{
      bus: render_bus(bus),
      students: UchukuziInterfaceWeb.RolesView.render_students(students),
      crew_member: UchukuziInterfaceWeb.RolesView.render_crew_member(crew_member),
      route: %{
        id: route.id,
        name: route.name,
        path: route.path |> Enum.map(&render_location/1)
      }
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
      bus:
        with bus = %Bus{} <- Map.get(route, :bus) do
          %{id: bus.id, number_plate: bus.number_plate}
        else
          _ -> nil
        end
    }
  end

  def render("routes.json", %{routes: routes}) do
    routes
    |> render_many(__MODULE__, "route.json", as: :route)
  end

  def render("route.json", %{route: nil}) do
    nil
  end

  def render("route.json", %{route: route}) do
    %{
      id: route.id,
      name: route.name,
      path: route.path |> Enum.map(&render_location/1),
      bus:
        with bus = %Bus{} <- Map.get(route, :bus) do
          %{id: bus.id, number_plate: bus.number_plate}
        else
          _ -> nil
        end
    }
  end

  def render("fuel_reports.json", %{fuel_reports: fuel_reports}) do
    fuel_reports
    |> render_many(__MODULE__, "fuel_report.json", as: :fuel_report)
  end

  def render("fuel_report.json", %{fuel_report: fuel_report}) do
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

  def render_location(location) do
    %{
      lng: location.lng,
      lat: location.lat
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
end
