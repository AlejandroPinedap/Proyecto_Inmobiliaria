defmodule Inmobiliaria.Operations.OperationLogger do

  @file "data/results.log"

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
      "#{date};cliente=#{client};responsable=#{owner};" <>
      "propiedad=#{property_id};operacion=#{operation};" <>
      "ubicacion=#{city};precio=#{price};estado=completada\n"

    File.write!(@file, line, [:append])

    :ok
  end

  # =========================
  # VER HISTORIAL
  # =========================

  def show_history do

    if File.exists?(@file) do

      @file
      |> File.read!()
      |> IO.puts()

    else
      IO.puts("No hay operaciones")
    end
  end
end
