# defmodule TripTrackerTest do
#   use ExUnit.Case
#   doctest Uchukuzi
#   alias Uchukuzi.Tracking.TripSupervisor
#   alias Uchukuzi.Tracking.TripTracker
#   alias Uchukuzi.Common.Report
#   alias Uchukuzi.Common.Geofence
#   alias Uchukuzi.School.School
#   alias Uchukuzi.Common.Location
#   alias Uchukuzi.School.Bus
#   alias Uchukuzi.School.Bus
#   alias Uchukuzi.Tracking.StudentActivity
#   alias Uchukuzi.Roles.Student
#   alias Uchukuzi.Roles.Assistant
#   alias Uchukuzi.Tracking.BusesSupervisor
#   alias Uchukuzi.Tracking.BusSupervisor

#   setup do
#     try do
#       if pid = GenServer.whereis(BusSupervisor.via_tuple(sample_bus())) do
#         Supervisor.stop(pid, :normal)
#       end
#     catch
#       _ ->
#         nil
#     end

#     # :sys.terminate(BusesSupervisor, "setup")
#     # :sys.terminate(BusesSupervisor, "setup")
#     :ok
#   end

#   def sample_school(name \\ "name") do
#     {:ok, loc1} = Location.new(0, 0)
#     {:ok, loc2} = Location.new(0, 1)
#     {:ok, loc3} = Location.new(1, 0)
#     {:ok, loc4} = Location.new(1, 1)

#     {:ok, perimeter} =
#       Geofence.new(:school, [
#         loc1,
#         loc2,
#         loc3,
#         loc4
#       ])

#     School.new(name, perimeter)
#   end

#   def report(time, lon, lat) do
#     {:ok, location} = Location.new(lon, lat)
#     Report.new(time, location)
#   end

#   def sample_bus, do: %Bus{id: 1, number_plate: "KAU944P", device: [], route: [], assistants: []}

#   test "the trip tracker is restored with all its state on crash" do
#     bus = sample_bus()



#     trip_sup = TripSupervisor.pid_from(bus)

#     {:ok, trip_tracker} =
#       TripSupervisor.start_trip(
#         trip_sup,
#         sample_school(),
#         sample_bus(),
#         report(0, 0, 0)
#       )

#     report = report(0, 0, 0.5)
#     TripTracker.insert_report(trip_tracker, report)

#     report = report(2, 0.4, 0.5)
#     TripTracker.insert_report(trip_tracker, report)

#     state_before_crash = TripTracker.trip(trip_tracker)

#     Process.exit(trip_tracker, :kaboom)
#     :timer.sleep(10)

#     trip_tracker = GenServer.whereis(TripTracker.via_tuple(sample_bus()))

#     state_after_crash = TripTracker.trip(trip_tracker)

#     assert(state_before_crash == state_after_crash)
#   end

#   test "the trip tracker exits when trip is terminated" do
#     bus = sample_bus()



#     trip_sup = TripSupervisor.pid_from(bus)

#     {:ok, trip_tracker} =
#       TripSupervisor.start_trip(
#         trip_sup,
#         sample_school("name2"),
#         sample_bus(),
#         report(0, 0, 0)
#       )

#     # insert report outside school
#     report = report(0, 0, 10.5)
#     TripTracker.insert_report(trip_tracker, report)
#     :timer.sleep(10)

#     name = TripTracker.pid_from(sample_bus())

#     assert(nil == GenServer.whereis(name))

#     assert(
#       [] ==
#         :ets.lookup(
#           TripTracker.tableName(),
#           TripTracker.via_tuple(sample_bus())
#         )
#     )
#   end

#   test "student tracking works" do
#     bus = sample_bus()


#     trip_sup = TripSupervisor.pid_from(bus)

#     {:ok, trip_tracker} =
#       TripSupervisor.start_trip(
#         trip_sup,
#         sample_school("name3"),
#         bus,
#         report(0, 0, 0)
#       )

#     # insert report outside school
#     report = report(2, 0, 0.5)
#     TripTracker.insert_report(trip_tracker, report)

#     report = report(4, 0, 0.2)
#     TripTracker.insert_report(trip_tracker, report)

#     student = Student.new("James", "evening")

#     activity =
#       StudentActivity.new(
#         student,
#         StudentActivity.boarded_vehicle(),
#         3,
#         sample_bus(),
#         Assistant.new("Tony", "example@gmail.com", "password")
#       )

#     TripTracker.insert_student_activity(trip_tracker, activity)

#     assert TripTracker.students_onboard(trip_tracker) == MapSet.new([student])

#     activity =
#       StudentActivity.new(
#         student,
#         StudentActivity.exited_vehicle(),
#         3,
#         sample_bus(),
#         Assistant.new("Tony", "example@gmail.com", "password")
#       )

#     TripTracker.insert_student_activity(trip_tracker, activity)
#     assert TripTracker.students_onboard(trip_tracker) == MapSet.new()
#   end
# end
