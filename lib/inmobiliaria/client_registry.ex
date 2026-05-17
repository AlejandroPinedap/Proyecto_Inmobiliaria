defmodule Inmobiliaria.ClientRegistry do
  use GenServer

  # =========================
  # API PUBLICA
  # =========================

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Registrar cliente conectado
  def register(username, pid) do
    GenServer.cast(__MODULE__, {:register, username, pid})
  end

  # Desregistrar cliente desconectado
  def unregister(username) do
    GenServer.cast(__MODULE__, {:unregister, username})
  end

  # Buscar PID de un usuario
  def lookup(username) do
    GenServer.call(__MODULE__, {:lookup, username})
  end

  # =========================
  # CALLBACKS
  # =========================

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:register, username, pid}, state) do
    {:noreply, Map.put(state, username, pid)}
  end

  @impl true
  def handle_cast({:unregister, username}, state) do
    {:noreply, Map.delete(state, username)}
  end

  @impl true
  def handle_call({:lookup, username}, _from, state) do
    case Map.get(state, username) do
      nil -> {:reply, {:error, "Usuario no conectado"}, state}
      pid -> {:reply, {:ok, pid}, state}
    end
  end
end
