defmodule Inmobiliaria.NotificationManager do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state), do: {:ok, state}

  # Incrementar notificaciones de un usuario
  def increment(username) do
    GenServer.cast(__MODULE__, {:increment, username})
  end

  # Obtener conteo de un usuario
  def get_count(username) do
    GenServer.call(__MODULE__, {:get_count, username})
  end

  # Resetear conteo de un usuario
  def reset(username) do
    GenServer.cast(__MODULE__, {:reset, username})
  end

  @impl true
  def handle_cast({:increment, username}, state) do
    count = Map.get(state, username, 0)
    new_state = Map.put(state, username, count + 1)
    Phoenix.PubSub.broadcast(
      Inmobiliaria.PubSub,
      "notifications:#{username}",
      {:new_notification, count + 1}
    )
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:reset, username}, state) do
    new_state = Map.put(state, username, 0)
    Phoenix.PubSub.broadcast(
      Inmobiliaria.PubSub,
      "notifications:#{username}",
      {:new_notification, 0}
    )
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_count, username}, _from, state) do
    {:reply, Map.get(state, username, 0), state}
  end
end
