defmodule UchukuziInterfaceWeb.TrackingController do
  use UchukuziInterfaceWeb, :controller

  use Uchukuzi.Tracking.Model
  alias Uchukuzi.School.Bus
  alias UchukuziInterfaceWeb.SchoolView
  action_fallback(UchukuziInterfaceWeb.FallbackController)

  # Reports should come in the most recent first order
  def create_report(conn, %{"_json" => reports_json, "device_id" => imei}) do
    with {:ok, device} <- School.device_with_imei(imei),
         bus_id when not is_nil(bus_id) <- device.bus_id,
         bus <- Repo.get_by(Bus, id: bus_id) do
      reports =
        for report <- reports_json do
          # Uchukuzi.DiskDB.createTable("reports")
          with {:ok, location} <-
                 Location.new(report["lng"], report["lat"]),
               #  {:ok, time} <- DateTimeParser.parse_datetime(report["time"], assume_utc: true) do
               {:ok, time} <- DateTimeParser.parse_datetime(report["time"], assume_utc: true) do
            Report.new(time, location)
          end
        end

      reports = Enum.sort(reports, &(DateTime.compare(&2.time, &1.time) != :lt))

      Task.async(fn ->
        for report <- reports do
          Tracking.move(bus, report)

          :timer.sleep(100)

          bus
          |> Tracking.status_of()
          |> broadcast_location_update(bus, bus.school_id)
        end

        bus
        |> Tracking.status_of()
        |> broadcast_location_update(bus, bus.school_id)
      end)

      bus = Repo.preload(bus, :school)

      last_point =
        reports
        |> Enum.drop(Enum.count(reports) - 1)
        |> hd()

      if last_point && School.School.contains_point?(bus.school, last_point.location) do
        conn
        |> resp(201, "Inside")
      else
        conn
        |> resp(200, "Outside")
      end
    end
  end

  def broadcast_location_update(nil, _bus_id, _school_id) do
  end

  def broadcast_location_update(report, bus, school_id) do
    bus_id = bus.id

    students_onboard = Tracking.students_onboard(bus)

    output =
      report
      |> UchukuziInterfaceWeb.TrackingView.render_report()
      |> Map.put(:bus, bus_id)
      |> Map.put(:students_onboard, students_onboard)

    UchukuziInterfaceWeb.Endpoint.broadcast("school:#{school_id}", "bus_moved", output)

    if bus.route_id != nil do
      UchukuziInterfaceWeb.CustomerSocket.BusChannel.send_bus_location(bus.route_id, output)
    end
  end
end
