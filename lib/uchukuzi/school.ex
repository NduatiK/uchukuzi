defmodule Uchukuzi.School do
  @moduledoc """
  Module through which managers can modify school records.

  Provides access to school, bus and household data
  """

  use Uchukuzi.School.Model

  # ********* SCHOOL *********

  def create_school(%School{} = school, %Manager{} = manager) do
    School.set_manager(school, manager)
  end

  def buses_for(%School{} = _school) do
    {:ok, route} = Route.new("Ngong", [])
    {:ok, bus} = Bus.new("KAU365Q", %Device{imei: "imei"}, route)

    [bus]
  end

  def add_assistant(%School{} = school, %Assistant{} = assistant) do
    School.add_assistant(school, assistant)
  end

  def remove_assistant(%School{} = school, %Assistant{} = assistant) do
    School.remove_assistant(school, assistant)
  end

  def add_bus(%School{} = school, %Bus{} = bus) do
    School.add_bus(school, bus)
  end

  def remove_bus(%School{} = school, %Bus{} = bus) do
    School.remove_bus(school, bus)
  end

  def add_geofence_to_school(%School{} = school, %Geofence{} = geofence) do
    School.add_geofence(school, geofence)
  end

  def delete_geofence_from_school(%School{} = school, %Geofence{} = geofence) do
    School.delete_geofence(school, geofence)
  end

  # ********* BUS *********

  def assign_assistant_to_bus(%Bus{} = bus, %Assistant{} = assistant) do
    Bus.assign_assistant(bus, assistant)
  end

  def remove_assistant_from_bus(%Bus{} = bus, %Assistant{} = assistant) do
    Bus.assign_assistant(bus, assistant)
  end

  def set_device(%Bus{} = bus, %Device{} = device) do
    Bus.set_device(bus, device)
  end

  def remove_device(%Bus{} = bus, %Device{} = device) do
    Bus.remove_device(bus, device)
  end

  def create_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
    Bus.add_fuel_record(bus, record)
  end

  def delete_fuel_record(%Bus{} = bus, %FuelRecord{} = record) do
    Bus.delete_fuel_record(bus, record)
  end

  def schedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
    Bus.schedule_maintenance(bus, schedule)
  end

  def unschedule_maintenance(%Bus{} = bus, %ScheduledRepair{} = schedule) do
    Bus.unschedule_maintenance(bus, schedule)
  end

  def add_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
    Bus.add_maintenance_record(bus, record)
  end

  def delete_maintenance_record(%Bus{} = bus, %PerformedRepair{} = record) do
    Bus.delete_maintenance_record(bus, record)
  end

  # ********* Routes *********
end
