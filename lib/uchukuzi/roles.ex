defmodule Uchukuzi.Roles do
  @moduledoc """
  Module through users can be managed
  """

  use Uchukuzi.Roles.Model

  def create_manager(_args) do
    Manager.new("name", "email", "password")
  end

  def create_student(_args) do
    Student.new("name", :evening)
  end

  def create_guardian(_args) do
    Guardian.new("name", "email", "password")
  end

  def create_assistant(_args) do
    Assistant.new("name", "email", "password")
  end
end
