defmodule UchukuziInterfaceWeb.AuthController do
  use UchukuziInterfaceWeb, :controller

  # alias Uchukuzi.School
  # alias Uchukuzi.Common.{Location, Geofence}
  # alias Uchukuzi.Roles.Manager
  alias Uchukuzi.Roles

  def login_manager(conn, %{"email" => email, "password" => password}) do
    with {:ok, manager} <- Roles.login_manager(email, password) do
      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("manager.json", manager: manager, token: AuthManager.sign(manager.id))
    else
      {:error, _} ->
        conn
        |> resp(:unauthorized, "Unauthorized")
        |> send_resp()
    end
  end

  # def create_school(conn, %{"manager" => manager_params, "school" => school_params}) do
  #   with {:ok, center} <-
  #          Location.new(
  #            school_params["geo"]["lon"],
  #            school_params["geo"]["lat"]
  #          ),
  #        {:ok, geofence} <- Geofence.new_school_fence(center, school_params["geo"]["radius"]),
  #        school <- School.School.new(school_params["name"], geofence),
  #        manager <-
  #          Manager.new(
  #            manager_params["name"],
  #            manager_params["email"],
  #            manager_params["password"]
  #          ),
  #        school <- School.create_school(school, manager) do
  #     IO.inspect(school)

  #     conn
  #     |> resp(200, "")
  #   end
  # end
end
