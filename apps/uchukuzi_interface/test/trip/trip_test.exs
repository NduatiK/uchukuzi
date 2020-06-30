# ExUnit.start()

# defmodule UchukuziInterfaceWeb.TripTest do
#   use ExUnit.Case
#   use Phoenix.ConnTest
#   alias UchukuziInterfaceWeb.Router.Helpers, as: Routes

#   # The default endpoint for testing
#   @endpoint UchukuziInterfaceWeb.Endpoint

#   import Jason
#   alias Plug.Conn
#   import File


#   test "emulate trip", %{conn: conn} do
#     path =
#       "/Users/deepwork/Documents/Implementation/server2/uchukuzi_backend/apps/uchukuzi_interface/test/trip/test_trip.json"

#     {:ok, contents} = File.read(path)

#     {:ok, jsonArray} = Jason.decode(contents)

#     conn = Conn.put_req_header(conn, "content-type", "application/json")

#     Enum.reduce(jsonArray, 0, fn x, waited ->
#       {time, ""} = Integer.parse(x["time"])

#       :timer.sleep((time - waited) * 100)


#       device_id = 4901_5420_3237_500

#       {:ok, body} = Jason.encode([x])
#       conn = post(conn, "/api/tracking/devices/#{device_id}/reports", body)

#       time
#     end)
#   end

#   # test "GET /"
#   #   conn = get(conn, "/")
#   #   assert html_response(conn, 200) =~ "Welcome to Phoenix!"
#   # end
# end
