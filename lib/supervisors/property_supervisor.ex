defmodule Inmobiliaria.Supervisors.PropertySupervisor do

  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok,
      name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_property(property_data) do
    child_spec = {
      Inmobiliaria.Property.Property,
      property_data
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
