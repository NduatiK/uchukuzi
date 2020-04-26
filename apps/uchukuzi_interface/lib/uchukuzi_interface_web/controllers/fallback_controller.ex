defmodule UchukuziInterfaceWeb.FallbackController do
  use UchukuziInterfaceWeb, :controller
  alias Ecto.Changeset
  import UchukuziInterfaceWeb.ErrorHelpers

  def translate_errors(changeset) do
    Changeset.traverse_errors(changeset, &translate_error/1)
  end

  def prepend_changeset_errors_with_stage_name(changeset, step) do
    step_to_string = fn
      x when is_binary(x) -> x
      x -> String.to_existing_atom(x)
    end

    Map.put(
      changeset,
      :errors,
      changeset.errors
      |> Enum.reduce(%{}, fn {key, value}, errors ->
        errors
        |> Map.put(step_to_string.(step) <> "_" <> Atom.to_string(key), value)
      end)
    )
  end

  

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(UchukuziInterfaceWeb.ErrorView)
    |> render(:"404")
  end

  # Support for transactions
  def call(conn, {:error, stage_name, %Ecto.Changeset{} = changeset, _}) do
    changeset = prepend_changeset_errors_with_stage_name(changeset, stage_name)
    call(conn, {:error, changeset})
  end

  def call(conn, {:error, stage_name, %Ecto.Changeset{} = changeset}) do
    changeset = prepend_changeset_errors_with_stage_name(changeset, stage_name)
    call(conn, {:error, changeset})
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    error = translate_errors(changeset)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UchukuziInterfaceWeb.ErrorView)
    |> render(:"422", error: error)
  end

  def call(conn, {:error, error}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(UchukuziInterfaceWeb.ErrorView)
    |> render(:"422", error: error)
  end
end
