defmodule Inmobiliaria.Messages.MessageManager do

  # =========================
  # ENVIAR MENSAJE
  # =========================

  def send_message(
        property_id,
        client,
        owner,
        message
      ) do

    date =
      DateTime.utc_now()
      |> DateTime.to_string()

    line =
      "#{date};" <>
      "#{property_id};" <>
      "#{client};" <>
      "#{owner};" <>
      "#{message}\n"

    File.write!(
      "data/messages.log",
      line,
      [:append]
    )

    {:ok, "Mensaje enviado"}
  end

  # =========================
  # VER MENSAJES DE PROPIEDAD
  # =========================

  def get_property_messages(property_id) do

    if File.exists?("data/messages.log") do

      "data/messages.log"
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.filter(fn line ->

        case String.split(line, ";") do

          [_date, prop, _client, _owner, _msg] ->
            prop == property_id

          _ ->
            false
        end
      end)

    else
      []
    end
  end

  # =========================
  # VER MENSAJES DE OWNER
  # =========================

  def get_owner_messages(owner) do

    if File.exists?("data/messages.log") do

      "data/messages.log"
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.filter(fn line ->

        case String.split(line, ";") do

          [_date, _prop, _client, responsible, _msg] ->
            responsible == owner

          _ ->
            false
        end
      end)

    else
      []
    end
  end

  # =========================
  # MOSTRAR MENSAJES
  # =========================

  def show_messages(messages) do

    if Enum.empty?(messages) do

      IO.puts("No hay mensajes")

    else

      Enum.each(messages, fn msg ->
        IO.puts(msg)
      end)
    end
  end
end
