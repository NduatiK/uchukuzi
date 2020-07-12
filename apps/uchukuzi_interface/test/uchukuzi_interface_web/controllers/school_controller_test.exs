defmodule UchukuziInterfaceWeb.SchoolControllerTest do
  use UchukuziInterfaceWeb.ConnCase
  import UchukuziInterfaceWeb.TestHelpers
  alias UchukuziInterfaceWeb.AuthPlugs.ManagerAuth

  alias Uchukuzi.School
  alias Plug

  use PropCheck
  import PropCheck

  alias Uchukuzi.Repo

  @valid_bus %{
    number_plate: "KZZ123",
    route_id: nil,
    seats_available: 24,
    vehicle_type: "van"
  }

  defp setup_manager_and_school(), do: setup_manager_and_school(%{conn: build_conn()})

  defp setup_manager_and_school(%{conn: conn}) do
    %{manager: manager, school: school} = create_manager()

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> ManagerAuth.sign(manager))

    {:ok, manager: manager, school: school, conn: conn}
  end

  describe "create bus" do
    setup [:setup_manager_and_school]

    test "inserts bus when data is valid", %{conn: conn, school: school, manager: manager} do
      before_count = Enum.count(School.buses_for(school.id))

      response =
        conn
        |> post(Routes.school_path(conn, :create_bus), @valid_bus)
        |> json_response(201)

      assert response["number_plate"] == @valid_bus.number_plate
      assert response["seats_available"] == @valid_bus.seats_available
      assert response["vehicle_type"] == @valid_bus.vehicle_type

      assert Enum.count(School.buses_for(school.id)) == before_count + 1
    end

    test "doesnt insert bus when data is invalid", %{conn: conn, school: school, manager: manager} do
      before_count = Enum.count(School.buses_for(school.id))

      attempts = [
        {%{@valid_bus | number_plate: "KZZ12"}, "number_plate"},
        {%{@valid_bus | seats_available: -24}, "seats_available"},
        {%{@valid_bus | seats_available: 1000}, "seats_available"},
        {%{@valid_bus | vehicle_type: "invalid type"}, "vehicle_type"}
      ]

      for {invalid_bus, error_field} <- attempts do
        response =
          conn
          |> post(Routes.school_path(conn, :create_bus), invalid_bus)
          |> json_response(422)

          assert is_list(response["errors"]["detail"][error_field])
      end

      assert Enum.count(School.buses_for(school.id)) == before_count
    end
  end
end
