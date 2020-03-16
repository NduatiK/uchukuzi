defmodule Uchukuzi.Tracking.Trip do
  alias __MODULE__

  @trip_states [:ongoing, :ended]
  @trip_types [:mobile, :dormant]

  @enforce_keys [:reports]
  defstruct [:reports, :student_activities, :state, :start_time, :end_time, :type]

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
       state: :ongoing,
       type: type,
       start_time: initial_report.time
     }}
  end

  @spec insert_report(
          Uchukuzi.Tracking.Trip.t(),
          Uchukuzi.Tracking.Report.t(),
          Uchukuzi.School.School.t()
        ) :: {:error, <<_::192>>} | {:ok, Uchukuzi.Tracking.Trip.t()}
  def insert_report(%Trip{type: :mobile} = trip, %Report{} = report, %School{} = school) do
    reports = Enum.sort([report | trip.reports], &(&1.time >= &2.time))
    [latest_report | _] = reports

    state =
      if School.contains_point?(school, report.location) do
        :ongoing
      else
        :ended
      end

    {:ok, %Trip{trip | reports: reports, state: state, end_time: latest_report.time}}
  end

  @doc """
  When dealing with a dormant trip (one inside the school)
  """
  def insert_report(%Trip{type: :dormant} = trip, %Report{} = report, %School{} = school) do
    reports = Enum.sort([report | trip.reports], &(&1.time >= &2.time))

    state =
      if School.contains_point?(school, report.location) do
        :dormant
      else
        :ended
      end

    [latest_report | _] = reports

    {:ok, %Trip{trip | reports: reports, end_time: latest_report.time, state: state}}
  end

  def insert_report(%Trip{}, %Report{}, %School{}) do
    {:error, "this is not an ongoing trip"}
  end

  def insert_student_activity(%Trip{} = trip, %StudentActivity{} = student_activity) do
    if trip.start_time > student_activity.time || trip.end_time < student_activity.time do
      {:error, :activity_out_of_trip_bounds}
    end

    student_activity =
      student_activity
      |> StudentActivity.infer_location(trip)
      |> StudentActivity.set_inferred_location(student_activity)

    {:ok, %Trip{trip | student_activities: [student_activity | trip.student_activities]}}
  end
end
