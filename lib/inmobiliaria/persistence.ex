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
      |> Enum.map(fn user -> "#{user.username};#{user.password};#{user.role};#{user.points}\n" end)
      |> Enum.join("")

    File.write!(@users_file, content)
  end


  # ==========================
  # USERS: PARSE LINE
  # ==========================

  defp parse_user_line(line) do
    [username, password, role, points] =
      line
      |> String.trim()
      |> String.split(";")

      %{
        username: username,
        password: password,
        role: role,
        points: String.to_integer(points)
      }
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
    else
      []
    end
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
    [
      id,
      type,
      modality,
      city,
      price,
      owner,
      status,
      rooms,
      area,
      buyer
    ] =
      line
      |> String.trim()
      |> String.split(";")

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
  end

  # ==========================
  # PROPERTIES: PARSE LINE
  # ==========================

  defp format_property_line(property) do
    id = property.id
    type = property.type
    modality = property.modality
    city = property.city
    price = property.price
    owner = property.owner
    status = property.status
    rooms = property.rooms
    area = property.area
    buyer = property.buyer || ""

    "#{id};#{type};#{modality};#{city};#{price};#{owner};#{status};#{rooms};#{area};#{buyer}\n"
  end

end
