defmodule UchukuziInterfaceWeb.AuthPlugs.AssistantAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> user_token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <- verify(user_token) do
      cond do
        user = conn.assigns[:assistant] ->
          put_assistant(conn, user)

        user = user_id && Uchukuzi.Roles.get_assistant_by(id: user_id) ->
          put_assistant(conn, user)

        true ->
          assign(conn, :assistant, nil)
      end
    else
      _ ->
        assign(conn, :assistant, nil)
    end
  end

  defp put_assistant(conn, user) do
    conn
    |> assign(:assistant, user)
  end

  def authenticate_assistant(conn, _opts) do
    if conn.assigns.assistant do
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
