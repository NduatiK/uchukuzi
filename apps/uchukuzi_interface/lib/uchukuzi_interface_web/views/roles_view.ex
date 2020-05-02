defmodule UchukuziInterfaceWeb.RolesView do
  use UchukuziInterfaceWeb, :view

  def render("manager.json", %{manager: %Uchukuzi.Roles.Manager{} = manager, token: token}) do
    %{
      "creds" => %{
        "id" => manager.id,
        "name" => manager.name,
        "email" => manager.email,
        "token" => token,
        "school_id" => manager.school_id
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

  def render("guardian_login.json", %{
        guardian: %Uchukuzi.Roles.Guardian{} = guardian,
        students: students,
        token: token
      }) do
    %{
      "id" => guardian.id,
      "name" => guardian.name,
      "email" => guardian.email,
      "students" => render_students_with_bus(students),
      "token" => token
    }
  end

  def render("student_login.json", %{
        student: %Uchukuzi.Roles.Student{} = student,
        students: students,
        token: token
      }) do
    %{
      "id" => student.id,
      "name" => student.name,
      "email" => student.email,
      "students" => render_students_with_bus(students),
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
    render_crew_member(crew_member)
  end

  def render_crew_member(crew_member) do
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
      "phone_number" => guardian.phone_number,
      "students" => render_students(guardian.students)
    }
  end

  def render("students.json", %{students: students}) do
    render_students(students)
  end

  def render_students(%Ecto.Association.NotLoaded{}), do: nil

  def render_students(students), do: Enum.map(students, &render_student/1)

  def render_student(%Ecto.Association.NotLoaded{}) do
    nil
  end

  def render_student([%Uchukuzi.Roles.Student{} = student, phone_number, guardian_name]) do
    student
    |> render_student()
    |> Map.put("phone_number", phone_number)
    |> Map.put("guardian_name", guardian_name)
  end

  def render_students_with_bus(students) do
    Enum.map(students, &render_student_with_bus/1)
  end

  def render_student_with_bus({student, bus}) do
    IO.inspect(bus)

    student
    |> render_student
    |> Map.put("bus", UchukuziInterfaceWeb.SchoolView.render_bus(bus))
  end

  def render_student(%Uchukuzi.Roles.Student{} = student) do
    student = Uchukuzi.Repo.preload(student, :route)

    %{
      "id" => student.id,
      "name" => student.name,
      "email" => student.email,
      "travel_time" => student.travel_time,
      "home_location" => render_location(student.home_location),
      "pickup_location" => render_location(student.pickup_location),
      "route" => UchukuziInterfaceWeb.SchoolView.render_bus_route(student.route)
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
