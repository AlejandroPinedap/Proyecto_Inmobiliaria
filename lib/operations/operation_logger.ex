defmodule Inmobiliaria.Operations.OperationLogger do

  # =========================
  # REGISTRAR OPERACIÓN
  # =========================

  def log_operation(
        client,
        owner,
        property_id,
        operation,
        city,
        price
      ) do

    date =
      DateTime.utc_now()
      |> DateTime.to_string()

    line =
      "#{date};" <>
      "cliente=#{client};" <>
      "responsable=#{owner};" <>
      "propiedad=#{property_id};" <>
      "operacion=#{operation};" <>
      "ubicacion=#{city};" <>
      "precio=#{price};" <>
      "estado=completada\n"

    File.write!(
      "data/results.log",
      line,
      [:append]
    )

    :ok
  end

  # =========================
  # VER HISTORIAL
  # =========================

  def show_history do

    if File.exists?("data/results.log") do

      content =
        File.read!("data/results.log")

      if String.trim(content) == "" do

        IO.puts("No hay operaciones registradas")

      else

        IO.puts("\n=== HISTORIAL ===\n")
        IO.puts(content)
      end

    else

      IO.puts("No hay operaciones")
    end
  end
end
