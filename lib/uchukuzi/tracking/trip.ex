defmodule Uchukuzi.Tracking.Trip do
  alias __MODULE__

  defstruct [
    :start_time,
    :end_time,
    reports: [],
    student_activities: [],
    students: [],
    distance_covered: 0,
    state: :created
  ]

  alias Uchukuzi.Common.Location
  alias Uchukuzi.Common.Report
  alias Uchukuzi.Common.Geofence
  alias Uchukuzi.Tracking.StudentActivity

  @doc """

  """
  def new() do
    %Trip{}
  end

  def insert_report(
        %Trip{} = trip,
        %Report{} = report,
        %Geofence{} = school_perimeter
      ) do
    trip
    |> insert(report)
    |> update_distance_covered()
    |> update_state(school_perimeter, report)
  end

  def insert_student_activity(
        %Trip{} = trip,
        %StudentActivity{} = student_activity
      ) do
    with true <- trip.start_time < student_activity.time,
         true <- trip.end_time > student_activity.time do
      {:ok,
       trip
       |> insert(student_activity)}
    else
      false ->
        {:error, :activity_out_of_trip_bounds}
    end
  end

  defp insert(trip, %Report{} = report) do
    reports = Enum.sort([report | trip.reports], &(&1.time >= &2.time))
    [latest_report | _] = reports

    %Trip{
      trip
      | reports: reports,
        start_time: trip.start_time || latest_report.time,
        end_time: latest_report.time
    }
  end

  defp insert(trip, %StudentActivity{} = student_activity) do
    student_activity =
      student_activity
      # TODO - What happens when there are no reports?
      # TODO - Do we come back?
      # TODO - Can we fallback on the bus's current location
      |> StudentActivity.infer_location(trip)
      |> StudentActivity.set_inferred_location(student_activity)

    %Trip{trip | student_activities: [student_activity | trip.student_activities]}
  end

  @doc """
  Iterate through a trip's reports summing up the
  distances between neighbouring reports
  """
  def update_distance_covered(trip) do
    {distance_covered, _last_report} =
      trip.reports
      |> Enum.reduce({0, nil}, fn current_report, acc ->
        {sum, previous_report_or_nil} = acc

        previous_report = previous_report_or_nil || current_report

        distance = Location.distance_between(current_report.location, previous_report.location)

        {sum + distance, current_report}
      end)

    %{trip | distance_covered: distance_covered}
  end

  def update_state(%Trip{} = trip, %Geofence{} = school_perimeter, report) do
    inside_school = Geofence.contains_point?(school_perimeter, report.location)

    state =
      if inside_school and trip.distance_covered > 100 do
        :terminated
      else
        :ongoing
      end

    %{trip | state: state}
  end

  def end_trip(%Trip{} = trip) do
    student_activities =
      trip.student_activities
      |> Enum.map(fn student_activity ->
        student_activity
        |> StudentActivity.infer_location(trip)
        |> StudentActivity.set_inferred_location(student_activity)
      end)

    %{trip | student_activities: student_activities, state: :terminate}
  end

  def is_terminated(%Trip{state: :terminated}), do: true
  def is_terminated(_), do: false

  def latest_location(%Trip{} = trip) do
    hd(trip.reports).location
  end

  @doc """
  Find out which students are currently onboard the bus based on activities

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
