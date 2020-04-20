defmodule Uchukuzi do
  @moduledoc """
  Documentation for Uchukuzi.
  """

  def service_name(service_id) do
    {:via, Registry, {Uchukuzi.Registry, service_id}}
  end
end
