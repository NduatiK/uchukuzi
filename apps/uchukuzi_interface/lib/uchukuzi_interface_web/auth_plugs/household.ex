defmodule UchukuziInterfaceWeb.AuthPlugs.HouseholdAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> user_token] <- get_req_header(conn, "authorization"),
         {:ok, %{"role" => role, "id" => user_id, "type" => "bearer"}} <- verify(user_token) do
      cond do
        user = conn.assigns[:household] ->
          put_household(conn, user)

        user = role == "guardian" && user_id && Uchukuzi.Roles.get_guardian_by(id: user_id) ->
          put_household(conn, user)

        user = role == "student" && user_id && Uchukuzi.Roles.get_student_by(id: user_id) ->
          put_household(conn, user)

        true ->
          assign(conn, :household, nil)
      end
    else
      _ ->
        assign(conn, :household, nil)
    end
  end

  defp put_household(conn, user) do
    conn
    |> assign(:household, user)
  end

  def authenticate_household(conn, _opts) do
    if conn.assigns.household do
      conn
    else
      conn
      |> resp(:unauthorized, "Unauthorized")
      |> send_resp()
      |> halt()
    end
  end

  @salt "SbciCndS/RFrK4SzsbQai3oOU8dAI9G0eq0fSCz1hvblwJeS+6lJl1wLJ4F/Yirh"
  @day 86400

  def sign(user_id),
    do: Phoenix.Token.sign(UchukuziInterfaceWeb.Endpoint, @salt, user_id)

  def verify(token, max_age \\ 21 * @day),
    do: Phoenix.Token.verify(UchukuziInterfaceWeb.Endpoint, @salt, token, max_age: max_age)
end
