defmodule Uchukuzi.Tracking.Trip do
  alias __MODULE__

  use Uchukuzi.Tracking.Model

  if Mix.env() == :dev do
    # dublin
    @naive_timezone +1
  else
    # nairobi
    @naive_timezone 3
  end

  schema "trips" do
    belongs_to(:bus, Bus)

    field(:start_time, :utc_datetime)
    field(:end_time, :utc_datetime)

    has_one(:report_collection, ReportCollection, on_delete: :delete_all)

    field(:travel_time, :string)
    field(:distance_covered, :float)

    embeds_many(:student_activities, StudentActivity)
  end

  def new(bus) do
    %Trip{
      bus_id: bus.id,
      report_collection: ReportCollection.new()
    }
  end

  def insert_report(%Trip{} = trip, %Report{} = report) do
    trip
    |> insert_sorted(report)
  end

  defp insert_sorted(trip, %Report{} = report) do
    reports = Enum.sort([report | trip.report_collection.reports], &(&1.time >= &2.time))
    [latest_report | _] = reports

    report_collection = %{trip.report_collection | reports: reports}

    %Trip{
      trip
      | report_collection: report_collection,
        start_time: trip.start_time || latest_report.time,
        end_time: latest_report.time
    }
    |> infer_trip_travel_time()
  end

  def insert_student_activity(%Trip{} = trip, %StudentActivity{} = student_activity) do
    student_activity =
      student_activity
      |> StudentActivity.infer_location(trip)
      |> StudentActivity.set_inferred_location(student_activity)

    %Trip{trip | student_activities: [student_activity | trip.student_activities]}
  end

  def clean_up_trip(%Trip{} = trip) do
    trip
    |> update_distance_covered()
    |> update_student_activities_locations()
    |> infer_trip_travel_time()
  end

  def set_deviation_positions(%Trip{} = trip, positions) do
    count = Enum.count(trip.report_collection.crossed_tiles)

    deviation_positions =
      positions
      |> Enum.map(&(count - &1 - 1))

    %Trip{
      trip
      | report_collection: %{trip.report_collection | deviation_positions: deviation_positions}
    }
  end

  def add_crossed_tiles(%Trip{} = trip, crossed_tiles) do
    %Trip{trip | report_collection: %{trip.report_collection | crossed_tiles: crossed_tiles}}
  end

  @doc """
  Iterate through a trip's reports summing up the
  distances between neighbouring reports
  """
  def update_distance_covered(trip) do
    {distance_covered, _last_report} =
      trip.report_collection.reports
      |> Enum.reduce({0, nil}, fn current_report, acc ->
        {sum, previous_report_or_nil} = acc

        previous_report = previous_report_or_nil || current_report

        distance = Location.distance_between(current_report.location, previous_report.location)

        {sum + distance, current_report}
      end)

    %{trip | distance_covered: distance_covered}
  end

  def update_student_activities_locations(%Trip{} = trip) do
    student_activities =
      trip.student_activities
      |> Enum.map(fn student_activity ->
        student_activity
        |> StudentActivity.infer_location(trip)
        |> StudentActivity.set_inferred_location(student_activity)
      end)

    %{trip | student_activities: student_activities}
  end

  def travel_times() do
    ["morning", "evening"]
  end

  def infer_trip_travel_time(%Trip{} = trip) do
    hour = trip.start_time.hour + @naive_timezone

    # if Enum.count(trip.student_activities) > 0 do
    travel_time =
      cond do
        hour < 9 and hour > 4 ->
          "morning"

        hour < 21 and hour > 14 ->
          "evening"

        true ->
          ""
      end

    %{trip | travel_time: travel_time}
  end

  def latest_location(%Trip{} = trip) do
    hd(trip.report_collection.reports).location
  end

  @doc """
  Find out which students are currently
  onboard the bus based on activities
  """
  def students_onboard(%Trip{} = trip) do
    # Replay activities from start to finish to determine who is on on board
    trip.student_activities
    |> Enum.reverse()
    |> Enum.reduce(MapSet.new(), fn activity, students ->
      if StudentActivity.is_boarding?(activity) do
        students |> MapSet.put(activity.student)
      else
        students |> MapSet.delete(activity.student)
      end
    end)
  end
end
