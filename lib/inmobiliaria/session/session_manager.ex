defmodule Inmobiliaria.Session.SessionManager do

  use GenServer

  # =========================
  # START
  # =========================

  def start_link(_) do

    GenServer.start_link(
      __MODULE__,
      %{},
      name: __MODULE__
    )
  end

  # =========================
  # INIT
  # =========================

  @impl true
  def init(state) do
    {:ok, state}
  end

  # =========================
  # LOGIN
  # =========================

  def login(username, role) do

    GenServer.call(
      __MODULE__,
      {:login, username, role}
    )
  end

  # =========================
  # LOGOUT
  # =========================

  def logout do
    GenServer.call(__MODULE__, :logout)
  end

  # =========================
  # CURRENT USER
  # =========================

  def current_user do
    GenServer.call(__MODULE__, :current_user)
  end

  # =========================
  # HANDLE LOGIN
  # =========================

  @impl true
  def handle_call(
        {:login, username, role},
        _from,
        _state
      ) do

    state = %{
      username: username,
      role: role
    }

    {:reply, {:ok, state}, state}
  end

  # =========================
  # HANDLE LOGOUT
  # =========================

  @impl true
  def handle_call(:logout, _from, _state) do

    {:reply, :ok, %{}}
  end

  # =========================
  # HANDLE CURRENT
  # =========================

  @impl true
  def handle_call(:current_user, _from, state) do

    {:reply, state, state}
  end
end
