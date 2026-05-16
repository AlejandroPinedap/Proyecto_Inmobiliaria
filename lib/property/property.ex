defmodule Inmobiliaria.Property.Property do

  use GenServer

  alias Inmobiliaria.Users.UserManager
  alias Inmobiliaria.Operations.OperationLogger

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

    {:via, Registry,
      {Inmobiliaria.PropertyRegistry, property_id}}
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

        {:reply,
          {:error, "La propiedad no está disponible"},
          state}

      state.modality != "venta" ->

        {:reply,
          {:error, "La propiedad no es de venta"},
          state}

      true ->

        new_state =

          state
          |> Map.put(:status, :sold)
          |> Map.put(:buyer, client)

        UserManager.add_points(client, 10)

        UserManager.add_points(
          state.owner,
          15
        )

        OperationLogger.log_operation(
          client,
          state.owner,
          state.id,
          "compra",
          state.city,
          state.price
        )

        rewrite_property(new_state)

        {:reply,
          {:ok, "Propiedad comprada"},
          new_state}
    end
  end

  # =====================
  # RENT
  # =====================

  @impl true
  def handle_call({:rent, client}, _from, state) do

    cond do

      state.status != :available ->

        {:reply,
          {:error, "La propiedad no está disponible"},
          state}

      state.modality != "arriendo" ->

        {:reply,
          {:error, "La propiedad no es de arriendo"},
          state}

      true ->

        new_state =

          state
          |> Map.put(:status, :rented)
          |> Map.put(:tenant, client)

        UserManager.add_points(client, 8)

        UserManager.add_points(
          state.owner,
          12
        )

        OperationLogger.log_operation(
          client,
          state.owner,
          state.id,
          "arriendo",
          state.city,
          state.price
        )

        rewrite_property(new_state)

        {:reply,
          {:ok, "Propiedad arrendada"},
          new_state}
    end
  end

  # =========================
  # CARGAR PROPIEDADES
  # =========================

  def load_properties do

    if File.exists?("data/properties.dat") do

      "data/properties.dat"
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_property/1)

    else
      []
    end
  end

  # =========================
  # PARSEAR
  # =========================

  defp parse_property(line) do

    [id, type, modality, city,
     price, owner, status] =

      String.split(line, ";")

    %{
      id: id,
      type: type,
      modality: modality,
      city: city,
      price: String.to_integer(price),
      owner: owner,
      status: String.to_atom(status)
    }
  end

  # =========================
  # REESCRIBIR PROPIEDAD
  # =========================

  def rewrite_property(updated_property) do

    properties =
      load_properties()

    updated_properties =

      Enum.map(properties, fn property ->

        if property.id == updated_property.id do
          updated_property
        else
          property
        end
      end)

    content =

      Enum.map_join(updated_properties, "\n", fn p ->

        "#{p.id};" <>
        "#{p.type};" <>
        "#{p.modality};" <>
        "#{p.city};" <>
        "#{p.price};" <>
        "#{p.owner};" <>
        "#{p.status}"

      end)

    File.write!(
  "data/properties.dat",
  content <> "\n"
)
  end
end
