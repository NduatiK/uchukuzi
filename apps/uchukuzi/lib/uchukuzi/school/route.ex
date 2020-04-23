defmodule Uchukuzi.School.Route do
  @moduledoc """
  The school defined path that a bus is expected to
  follow in order to pick and drop students
  """
  alias __MODULE__

  use Uchukuzi.School.Model

  schema "routes" do
    field(:name, :string)

    embeds_many(:path, Location)

    belongs_to(:school, School)
    has_one(:bus, Bus)
  end


  def changeset(schema \\ %__MODULE__{}, params) do
    schema
    |> cast(params, [:name, :school_id])
    |> validate_required([:name, :school_id])
    |> cast_embed(:path, with: &Location.changeset/2)
  end
end
