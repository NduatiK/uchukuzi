defmodule UchukuziInterfaceWeb.SchoolView do
  use UchukuziInterfaceWeb, :view

  def render("buses.json", %{buses: buses}) do
    render_many(buses, __MODULE__, "bus.json", as: :bus)
  end

  def render("show.json", %{bus: bus}) do
    render_one(bus, __MODULE__, "bus.json", as: :bus)
  end

  def render("bus.json", %{bus: bus}) do
    %{
      id: bus.id,
      number_plate: bus.number_plate,
      vehicle_type: bus.vehicle_type,
      stated_milage: bus.stated_milage,
      seats_available: bus.seats_available,
      device: if(bus.device == nil, do: nil, else: bus.device.imei),
      route: if(Map.get(bus, :route) == nil, do: nil, else: bus.route)
    }
  end
end
