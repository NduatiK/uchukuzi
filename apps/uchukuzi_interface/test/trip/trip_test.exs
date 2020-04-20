defmodule UchukuziInterfaceWeb.TripTest do
  use ExUnit.Case
  use UchukuziInterfaceWeb.ConnCase

  import Jason
  import File

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Uchukuzi.Repo)
  end

  test "emulate trip", %{conn: conn} do
    {ok, contents} = File.read("test/trip/test_trip.json")

    {ok, jsonArray} = Jason.decode(contents)


    Enum.reduce(jsonArray, 0, fn x, waited ->
      {time, ""} = Integer.parse(x["time"])

      :timer.sleep((time - waited)*1000)
      IO.inspect(x,label: "Posting")
      conn = post(conn, "/api/school/buses/1/performed_repairs", x)

      time
    end)
  end

  # test "GET /"
  #   conn = get(conn, "/")
  #   assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  # end
end
