defmodule Uchukuzi.School.BusServer do
  use GenServer

  alias Uchukuzi.School.Bus
  alias Uchukuzi.Common.Report
  alias Uchukuzi.School.BusesSupervisor
  alias __MODULE__

  defmodule State do
    alias __MODULE__
    defstruct [:last_seen, :bus]

    def set_location(%State{} = state, %Report{} = report) do
      %{state | last_seen: report}
    end

    def last_seen(%State{} = state) do
      Map.get(state, :last_seen)
    end

    def bus(%State{} = state) do
      Map.get(state, :bus)
    end
  end

  @spec start_link(Uchukuzi.School.Bus.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%Bus{} = bus), do: GenServer.start_link(__MODULE__, bus, name: via_tuple(bus))

  def via_tuple(%Bus{} = bus),
    do: Uchukuzi.service_name({__MODULE__, bus.id})

  def pid_from(%Bus{} = bus) do
    with nil <-
           bus
           |> BusServer.via_tuple()
           |> GenServer.whereis() do
      {:ok, _} = BusesSupervisor.start_bus(bus)

      bus
      |> BusServer.via_tuple()
      |> GenServer.whereis()
    end
  end

  def init(%Bus{} = bus) do
    state = %State{bus: bus}
    {:ok, state}
  end

  def bus(bus_server),
    do: GenServer.cast(bus_server, {:bus})

  def move(bus_server, %Report{} = report),
    do: GenServer.cast(bus_server, {:move, report})

  def last_seen(bus_server),
    do: GenServer.call(bus_server, :last_seen)

  def handle_cast({:move, location}, state) do
    {:noreply, State.set_location(state, location)}
  end

  def handle_call(:last_seen, _from, state) do
    {:reply, State.last_seen(state), state}
  end

  def handle_call(:bus, _from, state) do
    {:reply, State.bus(state), state}
  end

  # def pickup_student(bus_server, %Student{} = student),
  #   do: GenServer.cast(bus_server, {:pickup_server, student})

  # def dropoff_student(bus_server, %Student{} = student),
  #   do: GenServer.cast(bus_server, {:dropoff_student, student})

  # def dropoff_st_call(:location, _from, state) do
  #   {:reply, Map.get(state, :location), state}
  # end
end
