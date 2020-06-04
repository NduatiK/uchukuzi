defmodule UchukuziInterfaceWeb.TrackingView do
  use UchukuziInterfaceWeb, :view

  def render("trips.json", %{trips: trips}) do
    trips
    |> render_many(__MODULE__, "trip.json", as: :trip)
  end

  def render("trip.json", %{trip: nil}) do
    nil
  end

  def render("trip.json", %{trip: trip}) do
    render_trip(trip)
  end

  def render_trip(trip) do
    %{
      id: trip.id,
      bus: trip.bus_id,
      start_time: trip.start_time,
      end_time: trip.end_time,
      distance_covered: trip.distance_covered,
      travel_time: trip.travel_time,
      reports: render_reports(trip.report_collection),
      student_activities: Enum.map(trip.student_activities, &render_student_activity/1),
      crossed_tiles: render_crossed_tiles(trip.report_collection),
      deviations: render_deviations(trip.report_collection)

      # student_activities:
      #   Enum.map(
      #     [
      #       %Uchukuzi.Tracking.StudentActivity{
      #         activity: "boarded_vehicle",
      #         crew_member_id: "1",
      #         id: "123",
      #         infered_location: %Uchukuzi.Common.Location{lat: 53.294594, lng: -6.308969},
      #         student_id: 1,
      #         time: ~U[2012-11-19 16:38:08Z]
      #       },
      #       %Uchukuzi.Tracking.StudentActivity{
      #         activity: "boarded_vehicle",
      #         crew_member_id: "1",
      #         id: "123",
      #         infered_location: %Uchukuzi.Common.Location{lat: 53.294594, lng: -6.308969},
      #         student_id: 1,
      #         time: ~U[2012-11-19 16:38:08Z]
      #       }
      #     ],
      #     &render_student_activity/1
      #   ),
    }
  end

  def render_student_activity(report) do
    # field(:crew_member_id, :integer)
    %{
      location: render_location(report.infered_location),
      time: report.time,
      activity: report.activity,
      student: report.student_id,
      student_name: student_name(report.student_id)
    }
  end

  def student_name(student_id) do
    case Uchukuzi.Repo.get(Uchukuzi.Roles.Student, student_id) do
      nil -> nil
      student -> student.name
    end
  end

  def render_location(location) do
    %{
      lng: location.lng,
      lat: location.lat
    }
  end

  def render_reports(nil), do: nil
  def render_reports(%Ecto.Association.NotLoaded{}), do: []

  def render_reports(%{reports: reports}) do
    Enum.map(reports, &render_report/1)
  end

  def render_crossed_tiles(nil), do: nil
  def render_crossed_tiles(%Ecto.Association.NotLoaded{}), do: []

  def render_crossed_tiles(%{crossed_tiles: crossed_tiles}),
    do: crossed_tiles |> Enum.map(&render_location/1)

  def render_deviations(nil), do: nil
  def render_deviations(%Ecto.Association.NotLoaded{}), do: []
  def render_deviations(%{deviation_positions: deviations}), do: deviations

  def render_report(nil), do: nil

  def render_report(report) do
    %{
      bus: Map.get(report, :bus),
      location: render_location(report.location),
      time: report.time,
      speed: Float.round(report.speed + 0.0, 1),
      bearing: Float.round(report.bearing + 0.0, 1)
    }
  end
end
