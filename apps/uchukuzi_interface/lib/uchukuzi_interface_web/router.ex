defmodule UchukuziInterfaceWeb.Router do
  use UchukuziInterfaceWeb, :router

  if Mix.env() == :dev do
    # If using Phoenix
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

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
  end

  pipeline :manager_api do
    plug :accepts, ["json"]
    plug ManagerAuth
  end

  pipeline :assistant_api do
    plug :accepts, ["json"]
    plug AssistantAuth
    :authenticate_assistant
  end

  scope "/api", UchukuziInterfaceWeb do
    pipe_through :api

    post "/school/create", SchoolController, :create_school
    get "/school/households/:student_id/qr_code.svg", SchoolController, :get_qr_code

  end

  scope "/", UchukuziInterfaceWeb do

    get "assistant_login", AuthController, :deep_link_redirect
  end
  scope "/api/auth", UchukuziInterfaceWeb do
    pipe_through :api

    post "/manager/exchange_token", AuthController, :exchange_manager_token
    post "/manager/login", AuthController, :login_manager


    post "/assistant/request_token", AuthController, :request_assistant_token
    post "/assistant/exchange_token", AuthController, :exchange_assistant_token
  end

  scope "/api/school", UchukuziInterfaceWeb do
    pipe_through [:manager_api, :authenticate_manager]

    get "/buses", SchoolController, :list_buses
    get "/buses/:bus_id", SchoolController, :get_bus
    patch "/buses/:bus_id", SchoolController, :update_bus

    post "/buses", SchoolController, :create_bus
    get "/buses/:bus_id/crew", SchoolController, :get_crew_members_for_bus
    get "/buses/:bus_id/students_onboard", SchoolController, :get_students_onboard
    post "/buses/:bus_id/performed_repairs", SchoolController, :create_performed_repair
    get "/buses/:bus_id/fuel_reports", SchoolController, :list_fuel_reports
    post "/buses/:bus_id/fuel_reports", SchoolController, :create_fuel_report

    post "/devices", SchoolController, :register_device

    get "/households", SchoolController, :list_households
    post "/households", SchoolController, :create_houshold

    get "/crew", SchoolController, :list_crew_members
    get "/crew/:crew_member_id", SchoolController, :get_crew_member
    patch "/crew/:crew_member_id", SchoolController, :update_crew_member

    post "/crew", SchoolController, :create_crew_member

    get "/crew_and_buses", SchoolController, :list_crew_and_buses
    patch "/crew_and_buses", SchoolController, :update_crew_assignments



    post "/routes", SchoolController, :create_route
    get "/routes", SchoolController, :list_routes

    get "/routes/routes_available/", SchoolController, :list_routes_available
  end

  scope "/api/school/assistant", UchukuziInterfaceWeb do
    pipe_through [:assistant_api, :authenticate_assistant]

    get "/routes/:assistant_id", SchoolController, :route_for_assistant
  end

  scope "/api/tracking", UchukuziInterfaceWeb do
    pipe_through [:manager_api, :authenticate_manager]

    get "/trips/:bus_id", TrackingController, :list_trips
  end

  scope "/api/tracking", UchukuziInterfaceWeb do
    pipe_through :api

    post "/devices/:device_id/reports", TrackingController, :create_report
  end
end
