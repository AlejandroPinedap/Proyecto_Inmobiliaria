defmodule Inmobiliaria.Property.PropertyManager do

  alias Inmobiliaria.Supervisors.PropertySupervisor

  @file "data/properties.dat"

  # =========================
  # CREAR PROPIEDAD
  # =========================

  def create_property(data) do

    save_property(data)

    PropertySupervisor.start_property(data)
  end

  # =========================
# GUARDAR PROPIEDAD
# =========================

def save_property(property) do

  line =
    "#{property.id};" <>
    "#{property.type};" <>
    "#{property.modality};" <>
    "#{property.city};" <>
    "#{property.price};" <>
    "#{property.owner};" <>
    "#{property.status}\n"

  File.write!(@file, line, [:append])
end

  # =========================
  # LISTAR PROPIEDADES
  # =========================

  def list_properties do

    if File.exists?(@file) do

      @file
      |> File.read!()
      |> String.split("
", trim: true)

    else
      []
    end
  end
  # =========================
# BUSCAR POR TIPO
# =========================

def search_by_type(type) do

  load_properties()
  |> Enum.filter(fn property ->

    property.type == type

  end)
end
# =========================
# BUSCAR POR CIUDAD
# =========================

def search_by_city(city) do

  load_properties()
  |> Enum.filter(fn property ->

    property.city == city

  end)
end
# =========================
# BUSCAR POR PRECIO
# =========================

def search_by_price(min, max) do

  load_properties()
  |> Enum.filter(fn property ->

    property.price >= min and
    property.price <= max

  end)
end
# =========================
# BUSCAR POR OWNER
# =========================

def search_by_owner(owner) do

  load_properties()
  |> Enum.filter(fn property ->

    property.owner == owner

  end)
end

# =========================
# BUSCAR MODALIDAD
# =========================

def search_by_modality(modality) do

  load_properties()
  |> Enum.filter(fn property ->

    property.modality == modality

  end)
end
# =========================
# DISPONIBLES
# =========================

def available_properties do

  load_properties()
  |> Enum.filter(fn property ->

    property.status == :available

  end)
end
# =========================
# MOSTRAR
# =========================

def show_properties(properties) do

  Enum.each(properties, fn property ->

    IO.puts(\"\"\"
    ------------------------
    ID: #{property.id}
    Tipo: #{property.type}
    Modalidad: #{property.modality}
    Ciudad: #{property.city}
    Precio: #{property.price}
    Estado: #{property.status}
    Propietario: #{property.owner}
    ------------------------
    \"\"\")

  end)
  end

end
