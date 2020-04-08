defmodule Uchukuzi.Tracking.StudentActivity do
  alias __MODULE__
  alias Uchukuzi.Tracking.Trip
  alias Uchukuzi.Common.Location
  alias Uchukuzi.Roles.Assistant

  @activities [:boarded_vehicle, :exited_vehicle]

  @enforce_keys [:student, :activity, :time, :reported_by]
  defstruct [:student, :activity, :time, :infered_location, :reported_by]

  def boarded(student, time \\ nil, %Assistant{} = assistant),
    do: new(student, :boarded_vehicle, time, assistant)

  def exited(student, time \\ nil, %Assistant{} = assistant),
    do: new(student, :exited_vehicle, time, assistant)

  defp new(student, activity, time, %Assistant{} = assistant)
       when activity in @activities,
       do: %StudentActivity{
         student: student,
         activity: activity,
         time: time || DateTime.utc_now(),
         reported_by: assistant
       }

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
    is_before_activity = fn report -> report.time < student_activity.time end
    is_after_activity = fn report -> not is_before_activity.(report) end

    report_before = Enum.find(trip.reports, nil, is_before_activity)
    report_after = Enum.find(trip.reports, report_before, is_after_activity)

    if report_before == nil and report_after == nil do
      nil
    else
      Location.new(
        (report_after.location.lng + report_before.location.lng) / 2,
        (report_after.location.lat + report_before.location.lat) / 2
      )
    end
  end

  def is_boarding?(%StudentActivity{activity: :boarded_vehicle}), do: true
  def is_boarding?(%StudentActivity{}), do: false
end
