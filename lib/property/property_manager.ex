defmodule Inmobiliaria.Property.PropertyManager do

  alias Inmobiliaria.Supervisors.PropertySupervisor

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

    File.write!(
      "data/properties.dat",
      line,
      [:append]
    )
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
  # PARSEAR PROPIEDAD
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
  # MOSTRAR PROPIEDADES
  # =========================

  def show_properties(properties) do

    if Enum.empty?(properties) do

      IO.puts("No se encontraron propiedades")

    else

      Enum.each(properties, fn property ->

        IO.puts("""
        ------------------------
        ID: #{property.id}
        Tipo: #{property.type}
        Modalidad: #{property.modality}
        Ciudad: #{property.city}
        Precio: #{property.price}
        Estado: #{property.status}
        Propietario: #{property.owner}
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
    |> Enum.each(fn property ->

      PropertySupervisor.start_property(property)

    end)

    IO.puts("Propiedades restauradas")
  end
end
