defmodule UchukuziInterfaceWeb.RouteSocket do
  use Phoenix.Socket
  # Any topics starting with bus go through BusChannel
  channel "routes:*", UchukuziInterfaceWeb.RouteChannel
  alias UchukuziInterfaceWeb.AuthPlugs.HouseholdAuth
  @spec connect(any, any, any) :: {:ok, any}

  def connect(params, socket, _connect_info) do
    with {:ok, %{"role" => role, "id" => user_id, "type" => "bearer"}} <-
           HouseholdAuth.verify(params["token"]) do
      cond do
        customer =
            role == "guardian" && user_id &&
              Uchukuzi.Roles.get_guardian_by(id: user_id) |> Uchukuzi.Repo.preload(:students) ->
          {:ok,
           socket
           |> assign(:customer, customer)
           |> assign(
             :allowed_routes,
             customer.students
             |> Enum.map(fn s -> s.route_id end)
             |> Enum.uniq()
           )}

        customer = role == "student" && user_id && Uchukuzi.Roles.get_student_by(id: user_id) ->
          {:ok,
           socket
           |> assign(:customer, customer)
           |> assign(:allowed_routes, [customer.route_id])}

        true ->
          :error
      end
    else
      _ ->
        :error
    end
  end

  def id(_socket), do: nil
end
