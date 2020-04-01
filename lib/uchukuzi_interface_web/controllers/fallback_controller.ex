defmodule UchukuziInterfaceWeb.FallbackController do
  use UchukuziInterfaceWeb, :controller
  alias Ecto.Changeset
  import UchukuziInterfaceWeb.ErrorHelpers

  def translate_errors(changeset) do
    Changeset.traverse_errors(changeset, &translate_error/1)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(UchukuziInterfaceWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    error = translate_errors(changeset)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UchukuziInterfaceWeb.ErrorView)
    |> render(:"422", error: error)
  end

  def call(conn, {:error, _, %Ecto.Changeset{} = changeset, _}) do
    error = translate_errors(changeset)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UchukuziInterfaceWeb.ErrorView)
    |> render(:"422", error: error)
  end
end
