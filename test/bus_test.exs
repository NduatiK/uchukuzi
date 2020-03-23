defmodule TripTrackerTest do
  use ExUnit.Case
  doctest Uchukuzi

  alias Uchukuzi.World.Tile
  alias Uchukuzi.Common.Location
  alias Uchukuzi.Common.Report
  alias Uchukuzi.School.Bus
  alias Uchukuzi.School.BusServer

  def bus(),
    do: %Bus{id: 1, number_plate: "KAU944P", device: [], route: [], assistants: []}

  def report(lon, lat, time) do
    {:ok, location} = Location.new(lon, lat)
    Report.new(time, location)
  end

  def setup do
    :ok
  end

  test "bus moves through the grid" do
    Application.put_env(:uchukuzi, "default_tile_size", 1)

    bus = bus()
    # :observer.start()

    Uchukuzi.School.move(bus, report(0, 0.5, 0))

    Uchukuzi.School.move(bus, report(2.5, 0.5, 1))

    :timer.sleep(50)
    Uchukuzi.School.move(bus, report(3.5, 1.5, 2))


    Uchukuzi.School.move(bus, report(5.5, 2.5, 3))
    Uchukuzi.School.move(bus, report(5.5, 3.5, 4))
    :observer.start()
    :timer.sleep(1_000)
    :timer.sleep(100_000)
  end
end
