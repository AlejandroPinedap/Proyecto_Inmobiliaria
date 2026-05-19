defmodule Inmobiliaria.Messages.MessageManager do
  @messages_file "data/messages.log"

  # =========================
  # ENVIAR MENSAJE
  # Formato: date;property_id;client;owner;sender;message
  # =========================

  def send_message(property_id, client, owner, sender, message) do
    File.mkdir_p!("data")
    date = DateTime.utc_now() |> DateTime.to_string()

    line =
      "#{date};" <>
        "#{property_id};" <>
        "#{client};" <>
        "#{owner};" <>
        "#{sender};" <>
        "#{message}\n"

    File.write!(@messages_file, line, [:append])
    {:ok, "Mensaje enviado"}
  end

  # =========================
  # MENSAJES DE UNA SALA PRIVADA
  # Sala = propiedad + cliente + owner (par único)
  # Soporta formato antiguo (sin sender) y nuevo (con sender)
  # =========================

  def get_conversation_messages(property_id, client, owner) do
    if File.exists?(@messages_file) do
      @messages_file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.flat_map(fn line ->
        case String.split(line, ";") do
          # Formato nuevo: con sender
          [date, prop, c, o, sender, msg]
          when prop == property_id and c == client and o == owner ->
            [%{date: date, property_id: prop, client: c, owner: o, sender: sender, message: msg}]

          # Formato antiguo: sin sender — inferimos que envió el client
          [date, prop, c, o, msg]
          when prop == property_id and c == client and o == owner ->
            [%{date: date, property_id: prop, client: c, owner: o, sender: c, message: msg}]

          _ ->
            []
        end
      end)
    else
      []
    end
  end

  # =========================
  # CONVERSACIONES ACTIVAS DE UN OWNER
  # Devuelve pares únicos {property_id, client} que le han escrito
  # =========================

  def get_owner_conversations(owner) do
    if File.exists?(@messages_file) do
      @messages_file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.flat_map(fn line ->
        case String.split(line, ";") do
          [_date, prop, client, o, _sender, _msg] when o == owner -> [{prop, client}]
          [_date, prop, client, o, _msg] when o == owner          -> [{prop, client}]
          _ -> []
        end
      end)
      |> Enum.uniq()
    else
      []
    end
  end

  # =========================
  # MENSAJES DE PROPIEDAD (compatibilidad)
  # =========================

  def get_property_messages(property_id) do
    if File.exists?(@messages_file) do
      @messages_file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.filter(fn line ->
        case String.split(line, ";") do
          [_date, prop, _c, _o, _sender, _msg] -> prop == property_id
          [_date, prop, _c, _o, _msg]           -> prop == property_id
          _ -> false
        end
      end)
    else
      []
    end
  end

  # =========================
  # MENSAJES DE OWNER (compatibilidad)
  # =========================

  def get_owner_messages(owner) do
    if File.exists?(@messages_file) do
      @messages_file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.filter(fn line ->
        case String.split(line, ";") do
          [_date, _prop, _c, o, _sender, _msg] -> o == owner
          [_date, _prop, _c, o, _msg]           -> o == owner
          _ -> false
        end
      end)
    else
      []
    end
  end

  # =========================
  # MOSTRAR MENSAJES (CLI)
  # =========================

  def show_messages(messages) do
    if Enum.empty?(messages) do
      IO.puts("No hay mensajes")
    else
      Enum.each(messages, &IO.puts/1)
    end
  end
end
