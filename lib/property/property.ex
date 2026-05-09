defmodule Inmobiliaria.Property.Property do

  use GenServer
  alias Inmobiliaria.Users.UserManager
  alias Inmobiliaria.Operations.OperationLogger
  alias Inmobiliaria.Supervisors.PropertySupervisor

  # =====================
  # CLIENT
  # =====================

  def start_link(property_data) do
    GenServer.start_link(__MODULE__, property_data)
  end

  def buy(pid, client) do
    GenServer.call(pid, {:buy, client})
  end

  def get_info(pid) do
    GenServer.call(pid, :get_info)
  end

  # =====================
  # SERVER
  # =====================

  @impl true
  def init(property_data) do

    state = property_data

    {:ok, state}
  end

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
      UserManager.add_points(state.owner, 15)

      OperationLogger.log_operation(
        client,
        state.owner,
        state.id,
        "compra",
        state.city,
        state.price
      )

      {:reply,
        {:ok, "Propiedad comprada"},
        new_state}
  end
end
  # =========================
# CARGAR PROPIEDADES
# =========================

def load_properties do

  if File.exists?(@file) do

    @file
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

  [id, type, modality, city, price, owner, status] =
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
# RESTAURAR PROCESOS
# =========================

def restore_properties do

  load_properties()
  |> Enum.each(fn property ->

    PropertySupervisor.start_property(property)

  end)

  IO.puts("Propiedades restauradas")
end


  def rent(pid, client) do
  GenServer.call(pid, {:rent, client})
end


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
      UserManager.add_points(state.owner, 12)

      OperationLogger.log_operation(
        client,
        state.owner,
        state.id,
        "arriendo",
        state.city,
        state.price
      )

      {:reply,
        {:ok, "Propiedad arrendada"},
        new_state}
  end
end

end
