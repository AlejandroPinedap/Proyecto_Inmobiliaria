defmodule Inmobiliaria.Application do
  use Application

  alias Inmobiliaria.Property.PropertyManager

  @impl true
  def start(_type, _args) do
    children = [
      # PubSub para chat en tiempo real
      {Phoenix.PubSub, name: Inmobiliaria.PubSub},

      # Gestor de notificaciones en tiempo real
      Inmobiliaria.NotificationManager,

      # Registry de propiedades
      {Registry, keys: :unique, name: Inmobiliaria.PropertyRegistry},

      # Gestor de sesiones
      Inmobiliaria.Session.SessionManager,

      # Registry de clientes conectados (chat)
      Inmobiliaria.ClientRegistry,

      # Supervisor de propiedades
      Inmobiliaria.Supervisors.PropertySupervisor,

      # Phoenix
      InmobiliariaWeb.Endpoint
    ]

    opts = [
      strategy: :one_for_one,
      name: Inmobiliaria.Supervisor
    ]

    {:ok, pid} = Supervisor.start_link(children, opts)

    PropertyManager.restore_properties()

    {:ok, pid}
  end
end
