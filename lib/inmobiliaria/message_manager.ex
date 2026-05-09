defmodule Inmobiliaria.Messages.MessageManager do

  @file "data/messages.log"

  # =========================
  # ENVIAR MENSAJE
  # =========================

  def send_message(property_id, client, owner, message) do

    date =
      DateTime.utc_now()
      |> DateTime.to_string()

    line =
      "#{date};#{property_id};#{client};#{owner};#{message}\n"

    File.write!(@file, line, [:append])

    {:ok, "Mensaje enviado"}
  end

  # =========================
  # VER MENSAJES DE UNA PROPIEDAD
  # =========================

  def get_property_messages(property_id) do

    if File.exists?(@file) do

      @file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.filter(fn line ->

        [_date, prop, _client, _owner, _msg] =
          String.split(line, ";")

        prop == property_id
      end)

    else
      []
    end
  end

  # =========================
  # VER MENSAJES DE UN OWNER
  # =========================

  def get_owner_messages(owner) do

    if File.exists?(@file) do

      @file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.filter(fn line ->

        [_date, _prop, _client, responsible, _msg] =
          String.split(line, ";")

        responsible == owner
      end)

    else
      []
    end
  end
end
