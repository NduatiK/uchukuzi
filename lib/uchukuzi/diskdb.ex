defmodule Uchukuzi.DiskDB do
  @moduledoc """
  A simple ETS based dB.
  """

  @doc """
  Create the tables listed in the @tables attribute
  """
  def createTable(table_name) when is_binary(table_name),
    do: String.to_atom(table_name)

  def createTable(table_name) do
    :dets.open_file(table_name, type: :set)
    # :dets.insert(table_name, {"count", 0, "metadata"})

    {:ok, catalogue} = :dets.open_file(__MODULE__, type: :set)
    :dets.insert(catalogue, {table_name, table_name})
  end

  @doc """
  Destroys all tables
  """
  def destroyTables do
    tables = :dets.select(__MODULE__, [{{:_, :"$1"}, [], [:"$1"]}])

    for table <- tables do
      :dets.delete_all_objects(table)
    end
  end

  @doc """
  Retrieve the value with the given key from the named table.
  """

  def get(id, table) when is_binary(table) do
    get(id, String.to_existing_atom(table))
  end

  def get(id, table) do
    # :dets.lookup(table, id)

    case :dets.lookup(table, id) do
      [] -> {:error, "does not exist"}
      [{_key, record} | _] -> {:ok, record}
    end
  end

  @doc """
  Retrieve all values from the named table.
  """
  def get_all(table) when is_binary(table) do
    get_all(String.to_existing_atom(table))
  end

  def get_all(table) do
    # Select from the table the second item in the kv pair,
    # apply no filters
    # return the value
    :dets.select(table, [{{:_, :"$1"}, [], [:"$1"]}])
  end

  @doc """
  Insert a value into the named table.
  """
  def insert(record, table, at \\ nil)

  def insert(record, table, at) when is_binary(table) do
    insert(record, String.to_existing_atom(table), at)
  end

  def insert(record, table, at) do
    :dets.insert(table, {at, record})
    # case :dets.lookup(table, "count") do
      # [{_key, count, tag} | _] ->
        # :dets.insert(table, {"count", count + 1, tag})
        # :dets.insert(table, {at || count + 1, %{record: record, id: count}})

      # _ ->
      #   {:error, "does not exist"}
    # end
  end

  @doc """
  Delete a value from a named table.
  """
  def delete(id, table) do
    :dets.delete(table, id)
  end
end
