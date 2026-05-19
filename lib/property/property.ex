defmodule Inmobiliaria.Property.Property do
  use GenServer

  alias Inmobiliaria.Users.UserManager
  alias Inmobiliaria.Operations.OperationLogger
  alias Inmobiliaria.Property.PropertyManager

  # =====================
  # CLIENT
  # =====================

  def start_link(property_data) do
    GenServer.start_link(
      __MODULE__,
      property_data,
      name: via_tuple(property_data.id)
    )
  end

  # =====================
  # COMPRAR
  # =====================

  def buy(property_id, client) do
    GenServer.call(
      via_tuple(property_id),
      {:buy, client}
    )
  end

  # =====================
  # ARRENDAR
  # =====================

  def rent(property_id, client) do
    GenServer.call(
      via_tuple(property_id),
      {:rent, client}
    )
  end

  # =====================
  # INFO
  # =====================

  def get_info(property_id) do
    GenServer.call(
      via_tuple(property_id),
      :get_info
    )
  end

  # =====================
  # REGISTRY
  # =====================

  def via_tuple(property_id) do
    {:via, Registry, {Inmobiliaria.PropertyRegistry, property_id}}
  end

  # =====================
  # SERVER
  # =====================

  @impl true
  def init(property_data) do
    {:ok, property_data}
  end

  # =====================
  # GET INFO
  # =====================

  @impl true
  def handle_call(:get_info, _from, state) do
    {:reply, state, state}
  end

  # =====================
  # BUY
  # =====================

  @impl true
  def handle_call({:buy, client}, _from, state) do
    cond do
      state.status != :available ->
        {:reply, {:error, "La propiedad no está disponible"}, state}

      state.modality != "venta" ->
        {:reply, {:error, "La propiedad no es de venta"}, state}

      true ->
        new_state =
          state
          |> Map.put(:status, :sold)
          |> Map.put(:buyer, client)

        UserManager.add_points(client, 10)
        UserManager.add_points(state.owner, 15)

        OperationLogger.log_operation(
          client,
          state.owner,
          state.id,
          "compra",
          state.city,
          state.price
        )

        PropertyManager.update_property(new_state)
        Inmobiliaria.NotificationManager.increment(state.owner)
        {:reply, {:ok, "Propiedad comprada exitosamente"}, new_state}
    end
  end

  # =====================
  # RENT
  # =====================

  @impl true
  def handle_call({:rent, client}, _from, state) do
    cond do
      state.status != :available ->
        {:reply, {:error, "La propiedad no está disponible"}, state}

      state.modality != "arriendo" ->
        {:reply, {:error, "La propiedad no es de arriendo"}, state}

      true ->
        new_state =
          state
          |> Map.put(:status, :rented)
          |> Map.put(:buyer, client)

        UserManager.add_points(client, 8)
        UserManager.add_points(state.owner, 12)

        OperationLogger.log_operation(
          client,
          state.owner,
          state.id,
          "arriendo",
          state.city,
          state.price
        )

        PropertyManager.update_property(new_state)
        Inmobiliaria.NotificationManager.increment(state.owner)

        {:reply, {:ok, "Propiedad arrendada exitosamente"}, new_state}
    end
  end
end
