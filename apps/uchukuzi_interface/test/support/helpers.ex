defmodule UchukuziInterfaceWeb.TestHelpers do
   alias Uchukuzi.School

  def create_manager(attrs \\ %{}) do
    manager_params =
      Enum.into(attrs, %{
        name: "Manager Name",
        email: "manager@example.com",
        password: "password123",
        email_verified: true
      })

    center = %{lng: 36, lat: 0}
    geofence = %{radius: 50, center: center}
    school = School.School.new("School Name", geofence)

    {:ok, %{"manager" => manager, "school" => school}} =
      School.create_school(school, manager_params)

    %{manager: manager, school: school}
  end
end
