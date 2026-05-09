defmodule Inmobiliaria.Application do

  use Application

  alias Inmobiliaria.Property.PropertyManager

  @impl true
  def start(_type, _args) do

    children = [
      Inmobiliaria.Supervisors.PropertySupervisor
    ]

    opts = [
      strategy: :one_for_one,
      name: Inmobiliaria.Supervisor
    ]

    {:ok, pid} =
      Supervisor.start_link(children, opts)

    # Restaurar propiedades
    PropertyManager.restore_properties()

    {:ok, pid}
  end
end
