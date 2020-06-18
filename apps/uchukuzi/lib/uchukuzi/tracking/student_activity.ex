defmodule Uchukuzi.Tracking.StudentActivity do
  alias __MODULE__
  alias Uchukuzi.Roles.CrewMember
  use Uchukuzi.School.Model
  use Uchukuzi.Tracking.Model

  @activities ["boarded_vehicle", "exited_vehicle"]

  # @enforce_keys [:student, :activity, :time, :reported_by]
  # defstruct [:student, :activity, :time, :infered_location, :reported_by]
  embedded_schema do
    field(:student_id, :integer)
    field(:activity, :string)
    field(:time, :utc_datetime_usec)
    embeds_one(:infered_location, Location)
    field(:crew_member_id, :integer)
  end

  def boarded(student, time \\ nil, %CrewMember{} = assistant),
    do: new(student, "boarded_vehicle", time, assistant)

  def exited(student, time \\ nil, %CrewMember{} = assistant),
    do: new(student, "exited_vehicle", time, assistant)

  defp new(student, activity, time, %CrewMember{} = assistant)
       when activity in @activities,
       do: %StudentActivity{
         student_id: student.id,
         activity: activity,
         time: time || DateTime.utc_now(),
         crew_member_id: assistant.id
       }

  @doc """
  Set the location when this activity took place.

  This is usually infered from information available from a trip
  """
  def set_inferred_location(%Location{} = location, %StudentActivity{} = student_activity) do
    %StudentActivity{student_activity | infered_location: location}
  end

  def set_inferred_location(nil, %StudentActivity{} = student_activity) do
    %StudentActivity{student_activity | infered_location: nil}
  end

  @doc """
  Calculate where an activity happened based on a trip's information
  """
  def infer_location(_, %ReportCollection{reports: []}), do: nil

  def infer_location(%StudentActivity{} = student_activity, %ReportCollection{} = collection) do
    is_before_activity = fn report -> report.time < student_activity.time end

    # A bit complex but reduces runtime to O(n) instead of O(n²)
    result =
      collection.reports
      |> Enum.reduce(nil, fn report, acc ->
        case acc do
          # if the result has already been found
          {:ok, _} ->
            acc

          # if this is the first report
          nil ->
            if report |> is_before_activity.() do
              {:ok, report.location}
            else
              report
            end

          # if this is this is a report n where n is not 1
          # ie there is a report that was not before the
          # activity (was after)
          report_after ->
            if report |> is_before_activity.() do
              Location.new(
                (report.location.lng + report_after.location.lng) / 2,
                (report.location.lat + report_after.location.lat) / 2
              )
            else
              report
            end
        end
      end)

    case result do
      {:ok, location} ->
        location

      _ ->
        nil
    end
  end

  def is_boarding?(%StudentActivity{activity: :boarded_vehicle}), do: true
  def is_boarding?(%StudentActivity{activity: "boarded_vehicle"}), do: true
  def is_boarding?(%StudentActivity{}), do: false
end
