defmodule UchukuziInterfaceWeb.TrackingController do
  use UchukuziInterfaceWeb, :controller

  use Uchukuzi.Tracking.Model
  alias Uchukuzi.School.Bus

  action_fallback(UchukuziInterfaceWeb.FallbackController)

  def create_report(conn, %{"_json" => reports_json, "device_id" => imei}) do
    with {:ok, device} <- School.device_with_imei(imei),
         bus_id when not is_nil(bus_id) <- device.bus_id,
         bus <- Repo.get_by(Bus, id: bus_id) do
      reports =
        for report <- reports_json do
          with {:ok, location} <-
                 Location.new(report["lng"], report["lat"]),
               {:ok, time} <- parse_time(report["time"]) do
            Report.new(time, location)
          end
        end

      last_point =
        reports
        |> Enum.reverse()
        |> hd()

      if last_point == nil do
        conn
        |> resp(200, "Outside")
      else
        reports = Enum.sort(reports, &(DateTime.compare(&2.time, &1.time) != :lt))

        Tracking.move(bus, reports)

        bus = Repo.preload(bus, :school)

        if last_point && School.School.contains_point?(bus.school, last_point.location) do
          conn
          |> resp(201, "Inside")
        else
          conn
          |> resp(200, "Outside")
        end
      end
    end
  end

  def parse_time(time) when time |> is_number() do
    parse_time("#{time}")
  end

  def parse_time(time) do
    DateTimeParser.parse_datetime(time, assume_utc: true)
  end
end
