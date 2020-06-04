defmodule UchukuziInterfaceWeb.ManagerSocket do
  use Phoenix.Socket
  alias UchukuziInterfaceWeb.AuthPlugs.ManagerAuth

  channel "school:*", UchukuziInterfaceWeb.SchoolChannel
  channel "trip:*", UchukuziInterfaceWeb.TripChannel

  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, manager_id} <- ManagerAuth.verify(token),
         manager when not is_nil(manager) <- Uchukuzi.Roles.get_manager_by(id: manager_id),
         school_id when not is_nil(school_id) <- manager.school_id do

      {:ok,
       socket
       |> assign(:manager_id, manager_id)
       |> assign(:school_id, school_id)}
    else
      _ ->
        # {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error
  def id(socket), do: "manager_socket:#{socket.assigns.manager_id}"
end
