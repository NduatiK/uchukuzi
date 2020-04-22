defmodule UchukuziInterfaceWeb.AuthController do
  use UchukuziInterfaceWeb, :controller

  use Uchukuzi.Roles.Model

  alias Uchukuzi.Roles
  alias UchukuziInterfaceWeb.Email.{Email, Mailer}

  def login_manager(conn, %{"email" => email, "password" => password}) do
    with {:ok, manager} <- Roles.login_manager(email, password),
         true <- manager.email_verified do
      manager = Repo.preload(manager, :school)

      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("manager.json", manager: manager, token: ManagerAuth.sign(manager.id))
    else
      false ->
        conn
        |> resp(
          :bad_request,
          "{\"errors\": {\"detail\": \"Please verify your email account before logging in\"} }"
        )
        |> send_resp()

      {:error, _} ->
        conn
        |> resp(:unauthorized, "Unauthorized")
        |> send_resp()
    end
  end

  def exchange_manager_token(conn, %{"token" => token}) do
    with {:ok, user_id} <- ManagerAuth.verify(token, 3600),
         manager when not is_nil(manager) <- Roles.get_manager_by(id: user_id),
         {:ok, manager} <- Roles.set_manager_email_verified(manager) do
      manager = Repo.preload(manager, :school)

      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("manager.json", manager: manager, token: ManagerAuth.sign(manager.id))
    else
      {:error, :expired} ->
        conn
        |> resp(:unauthorized, "expired")
        |> send_resp()

      {:error, _} ->
        conn
        |> resp(:unauthorized, "Unauthorized")
        |> send_resp()
    end
  end

  def request_assistant_token(conn, %{"email" => email}) do
    with assistant when not is_nil(assistant) <- Roles.get_assistant_by(email: email) do
      send_token_email_to(
        Repo.preload(assistant, :school),
        AssistantAuth.sign(assistant.id)
      )

      conn
      |> resp(200, "{}")
    else
      nil ->
        conn
        |> resp(:not_found, "Not found")
        |> send_resp()
    end
  end

  def exchange_assistant_token(conn, %{"email_token" => email_token}) do
    with {:ok, user_id} <- AssistantAuth.verify(email_token, 3600),
         {:ok, assistant} <- Roles.get_assistant_by(id: user_id) do
      assistant = Repo.preload(assistant, :school)

      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("assistant.json", assistant: assistant, token: AssistantAuth.sign(assistant.id))
    else
      {:error, :expired} ->
        conn
        |> resp(:unauthorized, "expired")
        |> send_resp()

      {:error, _} ->
        conn
        |> resp(:unauthorized, "Unauthorized")
        |> send_resp()
    end
  end

  def send_token_email_to(assistant, token) do
    # Create your email
    Email.send_token_email_to(assistant, token)
    # Send your email
    |> Mailer.deliver_now()
  end
end
