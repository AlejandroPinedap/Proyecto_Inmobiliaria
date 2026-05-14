defmodule Inmobiliaria.Property.PropertyManager do
  alias Inmobiliaria.Supervisors.PropertySupervisor

  @properties_file "data/properties.dat"

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

    File.write!(@properties_file, line, [:append])
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

    content =
      properties
      |> Enum.map(fn p ->
        "#{p.id};#{p.type};#{p.modality};#{p.city};#{p.price};#{p.owner};#{p.status}\n"
      end)
      |> Enum.join("")

    File.write!(@properties_file, content)
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
    if File.exists?(@properties_file) do
      @properties_file
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
    case String.split(line, ";") do
      [id, type, modality, city, price, owner, status] ->
        %{
          id: id,
          type: type,
          modality: modality,
          city: city,
          price: String.to_integer(price),
          owner: owner,
          status: String.to_atom(status)
        }

      _ ->
        nil
    end
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
        Estado: #{p.status}
        Propietario: #{p.owner}
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
    |> Enum.filter(fn p -> p != nil end)
    |> Enum.each(fn p -> PropertySupervisor.start_property(p) end)

    IO.puts("Propiedades restauradas")
  end
end
