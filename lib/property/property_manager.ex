defmodule Inmobiliaria.Property.PropertyManager do
  alias Inmobiliaria.Supervisors.PropertySupervisor
  alias Inmobiliaria.Persistence


  # =========================
  # CREAR PROPIEDAD
  # =========================

  def create_property(data) do
    properties = load_properties()
    id_exists = Enum.any?(properties, fn p -> p.id == data.id end)

    if id_exists do
      {:error, "Ya existe una propiedad con el ID #{data.id}"}
    else
      save_property(data)
      PropertySupervisor.start_property(data)
      {:ok, "Propiedad creada"}
    end
  end

  # =========================
  # GUARDAR PROPIEDAD (append)
  # Formato: id;type;modality;city;price;owner;status;rooms;area;buyer
  # =========================

  def save_property(property) do
    Persistence.save_property(property)
  end

  # =========================
  # ACTUALIZAR PROPIEDAD
  # =========================

  def update_property(updated) do
    properties =
      load_properties()
      |> Enum.map(fn p ->
        if p.id == updated.id, do: updated, else: p
      end)

    rewrite_properties(properties)
  end

  # =========================
# ELIMINAR PROPIEDAD
# =========================

def delete_property(id) do
  properties =
    load_properties()
    |> Enum.reject(fn p -> p.id == id end)

  rewrite_properties(properties)
  {:ok, "Propiedad eliminada"}
end

  # =========================
  # REESCRIBIR TODAS
  # =========================

  def rewrite_properties(properties) do
    Persistence.rewrite_properties(properties)
  end

  # =========================
  # LISTAR PROPIEDADES
  # =========================

  def list_properties do
    load_properties()
  end

  # =========================
  # CARGAR PROPIEDADES
  # =========================

  def load_properties do
    Persistence.load_properties()
  end

  # =========================
  # BUSCAR POR BUYER (historial de cliente)
  # =========================

  def search_by_buyer(buyer) do
    load_properties()
    |> Enum.filter(fn p -> p.buyer == buyer end)
  end

  # =========================
  # BUSCAR POR TIPO
  # =========================

  def search_by_type(type) do
    load_properties()
    |> Enum.filter(fn p -> p.type == type end)
  end

  # =========================
  # BUSCAR POR CIUDAD
  # =========================

  def search_by_city(city) do
    load_properties()
    |> Enum.filter(fn p -> p.city == city end)
  end

  # =========================
  # BUSCAR POR PRECIO
  # =========================

  def search_by_price(min, max) do
    load_properties()
    |> Enum.filter(fn p -> p.price >= min and p.price <= max end)
  end

  # =========================
  # BUSCAR POR OWNER
  # =========================

  def search_by_owner(owner) do
    load_properties()
    |> Enum.filter(fn p -> p.owner == owner end)
  end

  # =========================
  # BUSCAR POR MODALIDAD
  # =========================

  def search_by_modality(modality) do
    load_properties()
    |> Enum.filter(fn p -> p.modality == modality end)
  end

  # =========================
  # DISPONIBLES
  # =========================

  def available_properties do
    load_properties()
    |> Enum.filter(fn p -> p.status == :available end)
  end

  # =========================
  # MOSTRAR PROPIEDADES (CLI)
  # =========================

  def show_properties(properties) do
    if Enum.empty?(properties) do
      IO.puts("No se encontraron propiedades")
    else
      Enum.each(properties, fn p ->
        IO.puts("""
        ------------------------
        ID: #{p.id}
        Tipo: #{p.type}
        Modalidad: #{p.modality}
        Ciudad: #{p.city}
        Precio: #{p.price}
        Habitaciones: #{p.rooms}
        Area: #{p.area}
        Estado: #{p.status}
        Propietario: #{p.owner}
        Comprador: #{p.buyer}
        ------------------------
        """)
      end)
    end
  end

  # =========================
  # RESTAURAR PROPIEDADES
  # =========================

  def restore_properties do
    load_properties()
    |> Enum.each(fn p -> PropertySupervisor.start_property(p) end)

    IO.puts("Propiedades restauradas")
  end
end
