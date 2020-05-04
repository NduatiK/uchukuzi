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
               {:ok, time} <- DateTimeParser.parse_datetime(report["time"], assume_utc: true) do
            Report.new(time, location)
          end
        end

      reports = Enum.sort(reports, &(DateTime.compare(&2.time, &1.time) != :lt))

      for report <- reports do
        Tracking.move(bus, report)
        # :timer.sleep(10)
        # bus
        # |> Tracking.status_of()
        # |> broadcast_location_update(bus.id, bus.school_id)
      end

      bus
      |> Tracking.status_of()
      |> broadcast_location_update(bus.id, bus.school_id)

      status =
        if Tracking.in_school?(bus) do
          201
        else
          200
        end

      conn
      |> resp(status, "")
    end
  end

  def broadcast_location_update(nil, _bus_id, _school_id) do
  end

  def broadcast_location_update(report, bus_id, school_id) do
    output =
      report
      |> SchoolView.render_last_seen()
      |> Map.put(:bus, bus_id)

    UchukuziInterfaceWeb.Endpoint.broadcast("school:#{school_id}", "bus_moved", output)
  end

  def list_trips(conn, %{"bus_id" => bus_id}) do
    with {bus_id, ""} <- Integer.parse(bus_id),
         {:ok, bus} <- School.bus_for(conn.assigns.manager.school_id, bus_id) do
      trips = Repo.preload(bus, :trips).trips

      conn
      |> render("trips.json", trips: trips)
    end
  end
end
