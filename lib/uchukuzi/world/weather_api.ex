defmodule Uchukuzi.World.WeatherAPI do
  use GenServer

  alias Uchukuzi.Common.Location

  defmodule WeatherRecord do
    defstruct [:time, :location, :status]

    def new(location, status) do
      %WeatherRecord{time: DateTime.utc_now(), location: location, status: status}
    end
  end

  def default_loc do
  end

  @base_url "api.openweathermap.org/data/2.5"

  @default_location (with {:ok, location} = Location.new(36.8219, -1.2921) do
                       location
                     end)

  @api_key "473cfd422b10fa68cbbc0695b500b721"

  @cache_radius 10_000
  @preferred_cache_ttl 60 * 45
  @cache_ttl 60 * 60

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    state = %{
      cache: []
    }

    send(self(), {:update_cache, @default_location})
    {:ok, state}
  end

  # HTTPPoison
  alias Uchukuzi.Common.Location

  def weather_at(%Location{} = location) do
    GenServer.call(GenServer.whereis(Uchukuzi.World.WeatherAPI), {:get_weather, location})
  end

  def handle_call({:get_weather, %Location{} = location}, _from, state) do
    cached_report =
      Enum.find(state.cache, fn weather_record ->
        time_ago = DateTime.diff(DateTime.utc_now(), weather_record.time)

        # only update if we do not have a record within 10km that was made in the last hour
        with true <- time_ago < @cache_ttl,
             true <- Location.distance_between(location, weather_record.location) < @cache_radius do
          if time_ago > @preferred_cache_ttl do
            send(self(), {:update_cache, location})
          end

          true
        end
      end)

    if(cached_report != nil) do
      {:reply, cached_report, state}
    else
      with {:ok, weather_status} <- get_weather_at(location) do
        weather = WeatherRecord.new(location, weather_status)
        cache = Enum.take([weather | state.cache], 10)
        {:reply, {:ok, weather}, Map.put(state, :cache, cache)}
      else
        _ ->
          {:reply, :error, state}
      end
    end
  end

  defp get_weather_at(%Location{} = location) do
    url = "#{@base_url}/weather?lat=#{location.lat}&lon=#{location.lng}&appid=#{@api_key}"

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get(url),
         {:ok, response} = Jason.decode(body) do
      {:ok,
       %{
         temp: Float.round(response["main"]["temp"] - 273.15, 2),
         # clouds.all Cloudiness, %
         clouds: response["clouds"]["all"]
         # rain.3h
       }}
    else
      e ->
        # IO.inspect(e)
        :error
    end
  end

  def handle_info({:update_cache, location}, state) do
    with {:ok, weather_status} <- get_weather_at(location) do
      weather_report = WeatherRecord.new(location, weather_status)

      {
        :noreply,
        Map.put(state, :cache, add_report_to_cache(state.cache, weather_report))
      }
    else
      _ ->
        {:noreply, state}
    end
  end

  def handle_info(_msg, _state) do
  end

  def add_report_to_cache(cache, report) do
    cache
    |> Enum.filter(fn x ->
      Location.distance_between(report.location, x.location) > @cache_radius
    end)

    Enum.take([report | cache], 10)
  end
end
