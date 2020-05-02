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

  def exchange_assistant_token(conn, %{"token" => email_token}) do
    with {:ok, user_id} <- AssistantAuth.verify(email_token, 3600),
         assistant when not is_nil(assistant) <- Roles.get_assistant_by(id: user_id) do
      assistant = Repo.preload(assistant, :school)

      conn
      |> put_view(UchukuziInterfaceWeb.RolesView)
      |> render("assistant.json", assistant: assistant, token: AssistantAuth.sign(assistant.id))
    else
      {:error, _} ->
        conn
        |> resp(:unauthorized, "expired")
        |> send_resp()

      _ ->
        conn
        |> resp(:not_found, "Unauthorized")
        |> send_resp()
    end
  end

  @spec deep_link_redirect_assistant(Plug.Conn.t(), any) :: Plug.Conn.t()
  def deep_link_redirect_assistant(%{query_params: %{"token" => token}} = conn, _) do
    conn
    |> redirect(external: "uchukuzi_assistant://uchukuzi.com/?token=#{token}")
  end

  def request_household_token(conn, %{"email" => email}) do
    cond do
      guardian = Roles.get_guardian_by(email: email) ->
        send_token_email_to(
          guardian,
          HouseholdAuth.sign(%{"role" => "guardian", "id" => guardian.id, "type" => "exchange"})
        )

        conn
        |> resp(200, "{}")

      student = Roles.get_student_by(email: email) ->
        send_token_email_to(
          Repo.preload(student, :school),
          HouseholdAuth.sign(%{"role" => "student", "id" => student.id, "type" => "exchange"})
        )

        conn
        |> resp(200, "{}")

      true ->
        conn
        |> resp(:not_found, "Not found")
        |> send_resp()
    end
  end

  def exchange_household_token(conn, %{"token" => email_token}) do
    with {:ok, %{"role" => role, "id" => id, "type" => "exchange"}} <-
           HouseholdAuth.verify(email_token, 3600) do
      cond do
        guardian = role == "guardian" && Roles.get_guardian_by(id: id) ->
          guardian = Repo.preload(guardian, :students)

          students =
            guardian.students
            |> preloadData()

          conn
          |> put_view(UchukuziInterfaceWeb.RolesView)
          |> render("guardian_login.json",
            guardian: guardian,
            students: students,
            token: HouseholdAuth.sign(%{"role" => role, "id" => id, "type" => "bearer"})
          )

        student = role == "student" && Roles.get_student_by(id: id) ->
          students =
            [student]
            |> preloadData()

          conn
          |> put_view(UchukuziInterfaceWeb.RolesView)
          |> render("student_login.json",
            students: students,
            token: HouseholdAuth.sign(%{"role" => role, "id" => id, "type" => "bearer"})
          )

        true ->
          conn
          |> resp(:not_found, "Unauthorized")
          |> send_resp()
      end
    else
      {:error, _} ->
        conn
        |> resp(:unauthorized, "expired")
        |> send_resp()

      _ ->
        conn
        |> resp(:not_found, "Unauthorized")
        |> send_resp()
    end
  end

  def preloadData(students) do
    for student <- students do
      with route <- Repo.preload(student, :route).route,
           bus <- Repo.preload(route, :bus).bus do
        {student, bus}
      end
    end
  end

  def deep_link_redirect_household(%{query_params: %{"token" => token}} = conn, _) do
    IO.inspect("uchukuzi://uchukuzi.com/?token=#{token}")

    conn
    |> redirect(external: "uchukuzi://uchukuzi.com/?token=#{token}")
  end

  def send_token_email_to(person, token) do
    # Create your email
    Email.send_token_email_to(person, token)
    # Send your email
    |> Mailer.deliver_now()
  end
end
