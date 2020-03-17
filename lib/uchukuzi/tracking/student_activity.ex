defmodule Uchukuzi.Tracking.StudentActivity do
  alias __MODULE__
  alias Uchukuzi.Tracking.Trip
  alias Uchukuzi.Tracking.Report
  alias Uchukuzi.Location
  alias Uchukuzi.School.Bus
  alias Uchukuzi.Roles.Assistant

  @activities [:boarded_vehicle, :exited_vehicle]

  @enforce_keys [:student, :activity, :bus, :time, :reported_by]
  defstruct [:student, :activity, :time, :bus, :infered_location, :reported_by]

  def new(student, activity, time, %Bus{} = bus, %Assistant{} = assistant)
      when activity in @activities do
    {:ok,
     %StudentActivity{
       student: student,
       activity: activity,
       time: time,
       bus: bus,
       reported_by: assistant
     }}
  end

  def new(_, _, _) do
    {:error, :invalid_activity}
  end

  @doc """
  Set the location when this activity took place.

  This is usually infered from information available from a trip
  """
  def set_inferred_location(%Location{} = location, %StudentActivity{} = student_activity) do
    %StudentActivity{student_activity | infered_location: location}
  end

  @doc """
  Calculate where an activity happened based on a trip's information
  """
  def infer_location(%StudentActivity{} = student_activity, %Trip{} = trip) do
    if trip.start_time > student_activity.time || trip.end_time < student_activity.time do
      {:error, :activity_out_of_trip_bounds}
    end

    is_before_activity = fn report -> report.time < student_activity.time end
    is_after_activity = fn report -> not is_before_activity.(report) end

    report_before = Enum.find(trip.reports, nil, is_before_activity)
    report_after = Enum.find(trip.reports, nil, is_after_activity)

    %Location{
      lon: (report_after.lon + report_before.lon) / 2,
      lat: (report_after.lat + report_before.lat) / 2
    }
  end

  def is_boarding?(%StudentActivity{activity: :boarded_vehicle}), do: true
  def is_boarding?(%StudentActivity{}), do: false
end
