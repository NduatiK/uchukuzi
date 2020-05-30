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

  pipeline :household_api do
    plug :accepts, ["json"]
    plug HouseholdAuth
    :authenticate_household
  end

  scope "/api", UchukuziInterfaceWeb do
    pipe_through :api

    post "/school/create", SchoolController, :create_school
    get "/school/households/:student_id/qr_code.svg", SchoolController, :get_qr_code
  end

  scope "/", UchukuziInterfaceWeb do
    get "/assistant_login", AuthController, :deep_link_redirect_assistant
    get "/household_login", AuthController, :deep_link_redirect_household
  end

  scope "/api/auth", UchukuziInterfaceWeb do
    pipe_through :api

    post "/manager/exchange_token", AuthController, :exchange_manager_token
    post "/manager/login", AuthController, :login_manager

    post "/assistant/request_token", AuthController, :request_assistant_token
    post "/assistant/exchange_token", AuthController, :exchange_assistant_token

    post "/household/request_token", AuthController, :request_household_token
    post "/household/exchange_token", AuthController, :exchange_household_token
  end

  scope "/api/auth/manager", UchukuziInterfaceWeb do
    pipe_through [:manager_api, :authenticate_manager]

    patch "/update_password", AuthController, :update_password
  end

  scope "/api/school", UchukuziInterfaceWeb do
    pipe_through [:manager_api, :authenticate_manager]
    get "/details", SchoolController, :school_details
    patch "/details", SchoolController, :edit_school_details
    post "/edit_location", SchoolController, :edit_school_location

    get "/buses", SchoolController, :list_buses
    post "/buses", SchoolController, :create_bus

    get "/buses/:bus_id", SchoolController, :get_bus
    patch "/buses/:bus_id", SchoolController, :update_bus
    get "/buses/:bus_id/crew", SchoolController, :get_crew_members_for_bus
    get "/buses/:bus_id/students_onboard", SchoolController, :get_students_onboard

    post "/buses/:bus_id/performed_repairs", SchoolController, :create_performed_repair

    get "/buses/:bus_id/fuel_reports", SchoolController, :list_fuel_reports
    post "/buses/:bus_id/fuel_reports", SchoolController, :create_fuel_report

    get "/buses/:bus_id/route", SchoolController, :get_bus_route
  end

  scope "/api/school", UchukuziInterfaceWeb do
    pipe_through [:manager_api, :authenticate_manager]
    post "/devices", SchoolController, :register_device

    get "/households/:guardian_id", SchoolController, :get_household
    patch "/households/:guardian_id", SchoolController, :update_household
    get "/households", SchoolController, :list_households
    post "/households", SchoolController, :create_houshold

    get "/crew", SchoolController, :list_crew_members
    get "/crew/:crew_member_id", SchoolController, :get_crew_member
    patch "/crew/:crew_member_id", SchoolController, :update_crew_member

    post "/crew", SchoolController, :create_crew_member

    get "/crew_and_buses", SchoolController, :list_crew_and_buses
    patch "/crew_and_buses", SchoolController, :update_crew_assignments
  end

  scope "/api/school", UchukuziInterfaceWeb do
    pipe_through [:manager_api, :authenticate_manager]

    get "/routes", SchoolController, :list_routes

    post "/routes", SchoolController, :create_route
    get "/routes/:route_id", SchoolController, :get_route
    patch "/routes/:route_id", SchoolController, :update_route
    delete "/routes/:route_id", SchoolController, :delete_route

    get "/routes_available/", SchoolController, :list_routes_available_for_bus
  end

  scope "/api/school/assistant", UchukuziInterfaceWeb do
    pipe_through [:assistant_api, :authenticate_assistant]

    get "/trip/start", SchoolController, :route_for_assistant
    post "/trip/student_boarded/:student_id/", SchoolController, :student_boarded
    post "/trip/student_exited/:student_id/", SchoolController, :student_exited
    get "/trip/end", SchoolController, :route_for_assistant
  end

  scope "/api/school", UchukuziInterfaceWeb do
    pipe_through [:manager_api, :authenticate_manager]

    get "/trips", SchoolController, :list_trips
    get "/trips/:trip_id", SchoolController, :trip_details
  end

  scope "/api/tracking", UchukuziInterfaceWeb do
    pipe_through :api

    post "/devices/:device_id/reports", TrackingController, :create_report
  end

  scope "/api/school/household", UchukuziInterfaceWeb do
    pipe_through [:household_api, :authenticate_household]

    get "/mine", SchoolController, :data_for_household
    post "/invite", AuthController, :invite_student
  end

  # scope "/", UchukuziInterfaceWeb do
  #   get "/uchukuzi_assistant:/uchukuzi.com", ApplicationController
  # end
end
