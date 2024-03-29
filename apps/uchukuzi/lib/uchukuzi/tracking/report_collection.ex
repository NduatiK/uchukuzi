defmodule Uchukuzi.Tracking.Trip.ReportCollection do
  use Uchukuzi.Tracking.Model

  schema "trip_reports" do
    belongs_to(:trip, Trip)

    embeds_many(:reports, Report)

    embeds_many(:crossed_tiles, Location)
    field(:deviation_positions, {:array, :integer})
  end

  def new do
    %ReportCollection{}
  end
end
