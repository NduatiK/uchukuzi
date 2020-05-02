defmodule UchukuziInterfaceWeb.AssisantSocket do
  use Phoenix.Socket
  alias UchukuziInterfaceWeb.AuthPlugs.AssistantAuth

  channel("assistant:*", UchukuziInterfaceWeb.SchoolChannel)

  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, assistant_id} <- AssistantAuth.verify(token),
         assistant when not is_nil(assistant) <-
           Uchukuzi.Roles.get_assistant_by(id: assistant_id),
         school_id when not is_nil(school_id) <- assistant.school_id do
      {:ok,
       socket
       |> assign(:assistant, assistant)
       |> assign(:school_id, school_id)}
    else
      _ ->
        # {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error
  def id(socket), do: "manager_socket:#{socket.assigns.manager.id}"
end
