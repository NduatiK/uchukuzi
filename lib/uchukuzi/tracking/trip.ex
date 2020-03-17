defmodule Uchukuzi.Tracking.Trip do
  alias __MODULE__

  @trip_states [:ongoing, :terminate]
  @trip_types [:mobile, :dormant]

  @enforce_keys [:reports]
  defstruct [:reports, :student_activities, :students, :state, :start_time, :end_time, :type]

  alias Uchukuzi.Location
  alias Uchukuzi.Tracking.Report
  alias Uchukuzi.School.School
  alias Uchukuzi.Tracking.StudentActivity

  @doc """
  Create a trip starting off with an initial report
  """
  def new(%Report{} = initial_report, %School{} = school) do
    type =
      if School.contains_point?(school, initial_report.location) do
        :dormant
      else
        :mobile
      end

    {:ok,
     %Trip{
       reports: [initial_report],
       student_activities: [],
       students: [],
       state: :ongoing,
       type: type,
       start_time: initial_report.time
     }}
  end

  def insert_report(
        %Trip{state: state, end_time: end_time} = trip,
        %Report{time: time} = report,
        %School{} = school
      )
      when state == :ongoing or time < end_time do
    trip =
      trip
      |> insert(report)
      |> update_distance_covered()
      |> update_state(school, report)

    {:ok, trip}
  end

  def insert_report(%Trip{}, %Report{}, %School{}) do
    {:error, "this is not an ongoing trip and the provided report occurs after trip was closed"}
  end

  def insert_student_activity(%Trip{} = trip, %StudentActivity{} = student_activity) do
    with true <- trip.start_time > student_activity.time,
         true <- trip.end_time < student_activity.time do
      trip =
        trip
        |> insert(student_activity)

      {:ok, trip}
    else
      false ->
        {:error, :activity_out_of_trip_bounds}
    end
  end

  def insert(trip, %Report{} = report) do
    reports = Enum.sort([report | trip.reports], &(&1.time >= &2.time))
    [latest_report | _] = reports

    %{trip | reports: reports, end_time: latest_report.time}
  end

  def insert(trip, %StudentActivity{} = student_activity) do
    student_activity =
      student_activity
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
        {sum, previous_report} = acc

        distance = Location.distance_between(current_report.location, previous_report.location)

        {sum + distance, current_report}
      end)

    %{trip | distance_covered: distance_covered}
  end

  def update_state(%Trip{type: type} = trip, school, report) do
    inside_school = School.contains_point?(school, report.location)

    state =
      cond do
        inside_school and type == :mobile ->
          :terminate

        not inside_school and type == :dormant ->
          :ongoing

        true ->
          :terminate
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

  def is_terminated(%Trip{state: :terminate}), do: true
  def is_terminated(_), do: false

  def latest_location(%Trip{} = trip) do
    hd(trip.reports).location
  end

  def students_onboard(%Trip{} = trip) do
    trip.student_activities
    |> Enum.reduce(MapSet.new(), fn activity, students ->
      cond do
        StudentActivity.is_boarding?(activity) ->
          students |> MapSet.put(activity.student)

        not StudentActivity.is_boarding?(activity) and activity.student in students ->
          students |> MapSet.delete(activity.student)

        true ->
          students
      end
    end)
  end
end
