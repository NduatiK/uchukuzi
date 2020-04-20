defmodule UchukuziInterfaceWeb.SchoolView do
  use UchukuziInterfaceWeb, :view

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
    %{
      id: bus.id,
      number_plate: bus.number_plate,
      vehicle_type: bus.vehicle_type,
      stated_milage: bus.stated_milage,
      seats_available: bus.seats_available,
      device: if(bus.device == nil, do: nil, else: bus.device.imei),
      route: if(Map.get(bus, :route) == nil, do: nil, else: bus.route),
      # route: bus.route,
      last_seen: render_last_seen(Map.get(params, :last_seen)),
      performed_repairs: render_performed_repairs(Map.get(bus, :performed_repairs))
    }
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
