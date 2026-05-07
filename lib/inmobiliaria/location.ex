defmodule Inmobiliaria.Location do
  @moduledoc """
  Modulo parar validar y cargar ubicaciones validas del sistema.
  las ubicaciones se leen desde data/location.dat
  """

  # @ruta_archivo es una constante del modulo
  @ruta_archivo "data/locations.dat"

  @doc """
  Cara todas la ubicaciones desde el archivo.
  retorna una lista de string con los nombres
  """
  def cargar_ubicaciones do
    case File.read(@ruta_archivo) do
      {:ok, contenido} ->
        contenido
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))

      {:error, motivo} ->
        IO.puts("Error leyendo ubicaciones: #{motivo}")
        []
    end
  end

  @doc """
  Verifica si una ubicacion es valida
  Retorna true o false
  """
  def valida?(ubicacion) do
    ubicaciones = cargar_ubicaciones()
    ubicacion in ubicaciones
  end

end
