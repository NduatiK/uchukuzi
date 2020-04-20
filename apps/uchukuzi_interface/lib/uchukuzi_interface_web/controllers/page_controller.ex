defmodule UchukuziInterfaceWeb.PageController do
  use UchukuziInterfaceWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
