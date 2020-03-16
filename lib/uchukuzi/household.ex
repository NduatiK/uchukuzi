defmodule Uchukuzi.Household do
  alias __MODULE__
  alias Uchukuzi.Roles.Guardian
  alias Uchukuzi.Roles.Student
  alias Uchukuzi.Location

  @enforce_keys [:home_location, :pickup_location, :guardian, :students]
  defstruct [:home_location, :pickup_location, :guardian, :students]

  def new(
        %Guardian{} = guardian,
        students,
        %Location{} = home_location,
        %Location{} = pickup_location
      )
      when is_list(students) do
    if Enum.all?(students, fn x -> Student.is_student(x) end) do
      {:ok,
       %Household{
         home_location: home_location,
         pickup_location: pickup_location,
         guardian: guardian,
         students: students
       }}
    else
      {:error, "students must only contain students"}
    end
  end
end
