defmodule Inmobiliaria.Persistence do
  @users_file "data/users.dat"
  @properties_file "data/properties.dat"

  # ==========================
  # USER: LOAD
  # ==========================

  def load_users do
    if File.exists?(@users_file) do
      @users_file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_user_line/1)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  # ==========================
  # USERS: SAVE ONE
  # ==========================

  def save_user(user) do
    File.mkdir_p!("data")

    line =
      "#{user.username};" <>
        "#{user.password};" <>
        "#{user.role};" <>
        "#{user.points}\n"

    File.write!(@users_file, line, [:append])
  end

  # ==========================
  # USERS: REWRITE ALL
  # ==========================

  def rewrite_users(users) do
    content =
      users
      |> Enum.map(fn user ->
        "#{user.username};#{user.password};#{user.role};#{user.points}\n"
      end)
      |> Enum.join("")

    File.write!(@users_file, content)
  end

  # ==========================
  # USERS: PARSE LINE
  # ==========================

  defp parse_user_line(line) do
    case line |> String.trim() |> String.split(";") do
      [username, password, role, points] ->
        %{
          username: username,
          password: password,
          role: role,
          points: String.to_integer(points)
        }

      _ ->
        # Linea con formato incorrecto  se descarta
        nil
    end
  end

  # ==========================
  # PROPERTIES: LOAD
  # ==========================

  def load_properties do
    if File.exists?(@properties_file) do
      @properties_file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_property_line/1)
      |> Enum.reject(&is_nil/1)
    else
      []
    end
  end

  # ==========================
  # PROPERTIES: SAVE ONE
  # ==========================

  def save_property(property) do
    File.mkdir_p!("data")
    buyer = Map.get(property, :buyer, "")

    line =
      "#{property.id};" <>
        "#{property.type};" <>
        "#{property.modality};" <>
        "#{property.city};" <>
        "#{property.price};" <>
        "#{property.owner};" <>
        "#{property.status};" <>
        "#{Map.get(property, :rooms, 0)};" <>
        "#{Map.get(property, :area, 0)};" <>
        "#{buyer}\n"

    File.write!(@properties_file, line, [:append])
  end

  # ==========================
  # PROPERTIES: REWRITE ALL
  # ==========================

  def rewrite_properties(properties) do
    content =
      properties
      |> Enum.map(&format_property_line/1)
      |> Enum.join("")

    File.write!(@properties_file, content)
  end

  # ==========================
  # PROPERTIES: PARSE LINE
  # ==========================

  defp parse_property_line(line) do
    case line |> String.trim() |> String.split(";") do
      [id, type, modality, city, price, owner, status, rooms, area, buyer] ->
        %{
          id: id,
          type: type,
          modality: modality,
          city: city,
          price: String.to_integer(price),
          owner: owner,
          status: String.to_atom(status),
          rooms: String.to_integer(rooms),
          area: String.to_integer(area),
          buyer: buyer
        }

      _ ->
        nil
    end
  end

  # ==========================
  # PROPERTIES: FORMAT LINE
  # ==========================

  defp format_property_line(property) do
    buyer = property.buyer || ""

    "#{property.id};" <>
      "#{property.type};" <>
      "#{property.modality};" <>
      "#{property.city};" <>
      "#{property.price};" <>
      "#{property.owner};" <>
      "#{property.status};" <>
      "#{property.rooms};" <>
      "#{property.area};" <>
      "#{buyer}\n"
  end
end
