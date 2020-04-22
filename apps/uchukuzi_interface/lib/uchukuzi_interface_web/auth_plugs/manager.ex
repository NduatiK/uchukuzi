defmodule UchukuziInterfaceWeb.AuthPlugs.ManagerAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> user_token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <- verify(user_token) do
      cond do
        user = conn.assigns[:manager] ->
          put_manager(conn, user)

        user = user_id && Uchukuzi.Roles.get_manager_by(id: user_id) ->
          put_manager(conn, user)

        true ->
          assign(conn, :manager, nil)
      end
    else
      _ ->
        assign(conn, :manager, nil)
    end
  end

  defp put_manager(conn, user) do
    conn
    |> assign(:manager, user)
  end

  def authenticate_manager(conn, _opts) do
    if conn.assigns.manager do
      conn
    else
      conn
      |> resp(:unauthorized, "Unauthorized")
      |> send_resp()
      |> halt()
    end
  end

  @salt "6t04lfTC2EeOIcaWQ+WlJbzhnK+JxehvSCGyDcvBXsKCoBjXncdOH2BI1/u7t+L2"
  @day 86400

  def sign(user_id),
    do: Phoenix.Token.sign(UchukuziInterfaceWeb.Endpoint, @salt, user_id)

  def verify(token, max_age \\ 14 * @day),
    do: Phoenix.Token.verify(UchukuziInterfaceWeb.Endpoint, @salt, token, max_age: max_age)
end
