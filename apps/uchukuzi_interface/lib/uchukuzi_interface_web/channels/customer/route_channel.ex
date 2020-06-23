defmodule UchukuziInterfaceWeb.CustomerSocket.PredictionsChannel do
  use UchukuziInterfaceWeb, :channel

  @moduledoc """
  A channel through which to update bus information on the
  front-end in realtime
  """

  # alias Uchukuzi.School
  # alias Uchukuzi.School.BusesSupervisor

  defp authorized?(socket, route_id) do
    Enum.member?(socket.assigns[:allowed_routes], route_id)
  end

  # We expect
  # * "predictions:route_id:tile_hash"
  def join("predictions:" <> tail, _payload, socket) do
    with {:ok, route_id, _tile_hash} = decode_topic(tail),
         true <- authorized?(socket, String.to_integer(route_id)) do
      {:ok, socket}
    else
      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def decode_topic(topic, consumed \\ "")

  def decode_topic(<<_head, (<<":">>)>>, _consumed) do
    {:error, "unterminated channel topic"}
  end

  def decode_topic(<<>>, _) do
    {:error, "unterminated channel topic"}
  end

  def decode_topic(<<head, <<":">>, tail::binary>>, consumed) do
    {:ok, consumed <> <<head>>, tail}
  end

  def decode_topic(<<head, tail::binary>>, consumed) do
    decode_topic(tail, consumed <> <<head>>)
  end

  def send_prediction(route_id, tile_hash, data) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "predictions:" <> Integer.to_string(route_id) <> ":" <> tile_hash,
      "update",
      data
    )
  end

  # * ------

  def send_event(route_id, tile_hash, event) do
    UchukuziInterfaceWeb.Endpoint.broadcast(
      "predictions:" <> Integer.to_string(route_id) <> ":" <> tile_hash,
      "approaching",
      event
    )
  end

  # intercept ["approaching", "update"]

  defp authorized_to_receive?(socket, msg) do
    case socket.assigns.student_ids
         |> Enum.filter(fn id ->
           Enum.member?(msg.students_onboard, id)
         end) do
      [] -> nil
      students -> students
    end
  end

  def handle_out(event, msg, socket) do
    cond do
      students = authorized_to_receive?(socket, msg) ->
        push(socket, event, Map.put(msg, :students_onboard, students))
        {:noreply, socket}

      true ->
        {:noreply, socket}
    end
  end
end
