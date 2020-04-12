defmodule UchukuziInterfaceWeb.RolesView do
  use UchukuziInterfaceWeb, :view

  def render("manager.json", %{manager: %Uchukuzi.Roles.Manager{} = manager, token: token}) do
    %{
      "creds" => %{
        "id" => manager.id,
        "name" => manager.name,
        "email" => manager.email,
        "token" => token
      },
      "location" => %{
        "lat" => manager.school.perimeter.center.lat,
        "lng" => manager.school.perimeter.center.lng
      }
    }
  end

  def render("assistant.json", %{
        assistant: %Uchukuzi.Roles.CrewMember{role: "assistant"} = assistant,
        token: token
      }) do
    %{
      "id" => assistant.id,
      "name" => assistant.name,
      "email" => assistant.email,
      "token" => token
    }
  end

  def render("crew_and_buses.json", %{crew_members: crew_members, buses: buses}) do
    %{
      "crew" => render_one(crew_members, __MODULE__, "crew_members.json", as: :crew_members),
      "buses" => render_one(buses, UchukuziInterfaceWeb.SchoolView, "buses.json", as: :buses)
    }
  end

  def render("crew_members.json", %{crew_members: crew_members}),
    do: render_many(crew_members, __MODULE__, "crew_member.json", as: :crew_member)

  def render("crew_member.json", %{crew_member: %Uchukuzi.Roles.CrewMember{} = crew_member}) do
    %{
      "id" => crew_member.id,
      "name" => crew_member.name,
      "email" => crew_member.email,
      "phone_number" => crew_member.phone_number,
      "role" => crew_member.role,
      "bus_id" => crew_member.bus_id
    }
  end

  def render("guardians.json", %{guardians: guardians}) do
    IO.inspect(guardians)

    guardians
    |> render_many(__MODULE__, "guardian.json", as: :guardian)
  end

  def render("guardian.json", %{guardian: %Uchukuzi.Roles.Guardian{} = guardian}) do
    %{
      "id" => guardian.id,
      "name" => guardian.name,
      "email" => guardian.email,
      "phone_number" => guardian.email,
      "students" => render_students(guardian.students)
    }
  end

  def render_students(%Ecto.Association.NotLoaded{}), do: nil

  def render_students(students), do: Enum.map(students, &render_student/1)

  def render_student(%Ecto.Association.NotLoaded{}) do
    nil
  end

  def render_student(%Uchukuzi.Roles.Student{} = student) do
    IO.inspect(student)

    %{
      "id" => student.id,
      "name" => student.name,
      "email" => student.email,
      "travel_time" => student.travel_time,
      "home_location" => render_location(student.home_location),
      "pickup_location" => render_location(student.pickup_location),
      "route" => "student.route_id"
    }
  end

  def render_location(nil), do: nil

  def render_location(%Uchukuzi.Common.Location{} = location) do
    %{
      lng: location.lng,
      lat: location.lat
    }
  end
end
