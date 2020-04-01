defmodule UchukuziInterfaceWeb.Router do
  use UchukuziInterfaceWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", UchukuziInterfaceWeb do
    pipe_through :browser
    get "/", PageController, :index
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug AuthManager
  end

  scope "/api", UchukuziInterfaceWeb do
    pipe_through :api

    post "/school/create", SchoolController, :create_school
  end

  scope "/api/auth", UchukuziInterfaceWeb do
    pipe_through :api

    post "/manager/login", AuthController, :login_manager
  end

  scope "/api/school", UchukuziInterfaceWeb do
    pipe_through [:api, :authenticate_manager]

    get "/buses", SchoolController, :list_buses
    get "/buses/:bus_id", SchoolController, :get_bus
    post "/buses", SchoolController, :create_bus

    post "/devices", SchoolController, :register_device
  end
end
