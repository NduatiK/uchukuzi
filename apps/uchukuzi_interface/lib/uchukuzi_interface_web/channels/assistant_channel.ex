defmodule UchukuziInterfaceWeb.AssistantChannel do
  use UchukuziInterfaceWeb, :channel

  @moduledoc """
  A channel through which to update bus information on the
  assistant front-end in realtime
  """

  alias Uchukuzi.{School, Tracking}
  # alias Uchukuzi.School.BusesSupervisor
  defp authorized?(socket, school_id) do
    socket.assigns[:school_id] == school_id
  end

  def join("school:" <> school_id, _payload, socket) do
    if authorized?(socket, String.to_integer(school_id)) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
end
