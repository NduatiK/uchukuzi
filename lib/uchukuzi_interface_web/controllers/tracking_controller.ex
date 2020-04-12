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
               {:ok, time} <- DateTimeParser.parse_datetime(report["time"], assume_utc: true),
               report <- Report.new(time, location) do
            report
          end
        end

      for report <- reports do
        Tracking.move(bus, report)
      end

      bus
      |> Tracking.where_is()
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
end

# def create(conn, %{"_json" => reports, "device_id" => device_id}) do
#   IO.inspect(reports)

#   cond do
#     _device = Uchukuzi.IoT.get_device(device_id) ->
#       for report_params <- Enum.reverse(reports) do
#         Uchukuzi.DiskDB.createTable("reports")

#         _report = %GPS{
#           location: %{latitude: report_params["lat"], longitude: report_params["lng"]},
#           bearing: Enum.random(1..130),
#           timestamp: DateTimeParser.parse_datetime(report_params["time"]),
#           device: device_id
#         }

#         # IO.inspect(report)
#         # Uchukuzi.DiskDB.insert(report, :reports)

#         # Uchukuzi.DiskDB.createTable(:routes)
#         # route = %{
#         #   name: "Ngong Road Route"
#         # }
#         # Uchukuzi.DiskDB.insert(route, :routes)
#         # UchukuziAPI.Endpoint.broadcast!("routes:1", "update", %{lat: report.location.latitude, lng: report.location.longitude})
#         {:ok, time} = DateTimeParser.parse_datetime(report_params["time"])

#         UchukuziAPI.RouteChannel.send_to_channel("routes:1", "update", %{
#           route_id: 1,
#           latitude: report_params["lat"],
#           longitude: report_params["lng"],
#           bearing: Enum.random(1..130),
#           timestamp: time
#         })
#       end

#       conn
#       |> send_resp(200, "")

#     true ->
#       conn
#       |> send_resp(404, "")
#   end

#   # end
# end
# end
