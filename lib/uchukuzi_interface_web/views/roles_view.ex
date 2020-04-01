defmodule UchukuziInterfaceWeb.RolesView do
  use UchukuziInterfaceWeb, :view

  def render("manager.json", %{manager: %Uchukuzi.Roles.Manager{} = manager, token: token}) do
    %{
      "id" => manager.id,
      "name" => manager.name,
      "email" => manager.email,
      "token" => token
    }
  end
end
