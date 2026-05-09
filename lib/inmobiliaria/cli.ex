defmodule Inmobiliaria.CLI do
  alias Inmobiliaria.Users.UserManager
  alias Inmobiliaria.Property.PropertyManager
  alias Inmobiliaria.Property.Property
  alias Inmobiliaria.Messages.MessageManager
  alias Inmobiliaria.Operations.OperationLogger

  def start do
    IO.puts("=== INMOBILIARIA ===")

    menu()
  end

  # =========================
  # MENU
  # =========================

  def menu do
    IO.puts("
1. Connect")
    IO.puts("2. Publicar propiedad")
    IO.puts("3. Listar propiedades")
    IO.puts("4. Comprar propiedad")
    IO.puts("5. Enviar mensaje")
    IO.puts("6. Ver mensajes")
    IO.puts("7. Ver historial")
    IO.puts("8. Ver ranking")
    IO.puts("9. Buscar por tipo")
    IO.puts("10. Buscar por ciudad")
    IO.puts("11. Buscar por precio")
    IO.puts("12. Salir")

    opcion = IO.gets("Seleccione: ") |> String.trim()

    case opcion do
      "1" ->
        connect_user()
        menu()

      "2" ->
        publish_property()
        menu()

      "3" ->
        list_properties()
        menu()

      "4" ->
        simulate_buy()
        menu()

      "5" ->
        send_message_cli()
        menu()

      "6" ->
        view_messages()
        menu()

      "7" ->
        show_history()
        menu()

      "8" ->
        show_ranking()
        menu()

      "9" ->
        search_type()
        menu()

      "10" ->
        search_city()
        menu()

      "11" ->
        search_price()
        menu()

      "12" ->
        IO.puts("Saliendo...")

      _ ->
        IO.puts("Opción inválida")
        menu()
    end
  end

  # =========================
  # LOGIN
  # =========================

  def connect_user do
    username = IO.gets("Usuario: ") |> String.trim()
    password = IO.gets("Password: ") |> String.trim()
    role = IO.gets("Rol: ") |> String.trim()

    response =
      UserManager.connect(username, password, role)

    IO.inspect(response)
  end

  # =========================
# PUBLICAR
# =========================

def publish_property do

  id =
    IO.gets("ID: ")
    |> String.trim()

  type =
    IO.gets("Tipo: ")
    |> String.trim()

  modality =
    IO.gets("Modalidad (venta/arriendo): ")
    |> String.trim()

  city =
    IO.gets("Ciudad: ")
    |> String.trim()

  price =
    IO.gets("Precio: ")
    |> String.trim()
    |> String.to_integer()

  owner =
    IO.gets("Propietario: ")
    |> String.trim()

  {:ok, _pid} =

    PropertyManager.create_property(%{
      id: id,
      type: type,
      modality: modality,
      city: city,
      price: price,
      owner: owner,
      status: :available
    })

  IO.puts("Propiedad registrada")
end

  # =========================
  # LISTAR
  # =========================

  def list_properties do
    properties = PropertyManager.list_properties()

    Enum.each(properties, fn p ->
      IO.puts(p)
    end)
  end

  # =========================
  # SIMULAR COMPRA
  # =========================

  def simulate_buy do
    {:ok, pid} =
      PropertyManager.create_property(%{
        id: "prop_test",
        type: "casa",
        city: "Armenia",
        price: 100_000,
        owner: "Carlos"
      })

    task1 =
      Task.async(fn ->
        Property.buy(pid, "Ana")
      end)

    task2 =
      Task.async(fn ->
        Property.buy(pid, "Juan")
      end)

    IO.inspect(Task.await(task1))
    IO.inspect(Task.await(task2))

    IO.inspect(Property.get_info(pid))
  end

  # =========================
  # ENVIAR MENSAJE
  # =========================

  def send_message_cli do
    property_id =
      IO.gets("ID propiedad: ")
      |> String.trim()

    client =
      IO.gets("Cliente: ")
      |> String.trim()

    owner =
      IO.gets("Responsable: ")
      |> String.trim()

    message =
      IO.gets("Mensaje: ")
      |> String.trim()

    response =
      MessageManager.send_message(
        property_id,
        client,
        owner,
        message
      )

    IO.inspect(response)
  end

  # =========================
  # VER MENSAJES
  # =========================

  def view_messages do
    owner =
      IO.gets("Responsable: ")
      |> String.trim()

    messages =
      MessageManager.get_owner_messages(owner)

    IO.puts("\n=== MENSAJES ===\n")

    Enum.each(messages, fn msg ->
      IO.puts(msg)
    end)
  end

  # =========================
  # HISTORIAL
  # =========================

  def show_history do
    IO.puts("\n=== HISTORIAL ===\n")

    OperationLogger.show_history()
  end

  # =========================
  # RANKING
  # =========================

  def show_ranking do
    ranking =
      UserManager.ranking()

    IO.puts("\n=== RANKING ===\n")

    Enum.each(ranking, fn user ->
      IO.puts("#{user.username} | #{user.role} | #{user.points} puntos")
    end)
  end
  # =========================
# BUSCAR TIPO
# =========================

def search_type do

  type =
    IO.gets("Tipo: ")
    |> String.trim()

  results =
    PropertyManager.search_by_type(type)

  PropertyManager.show_properties(results)
end
# =========================
# BUSCAR CIUDAD
# =========================

def search_city do

  city =
    IO.gets("Ciudad: ")
    |> String.trim()

  results =
    PropertyManager.search_by_city(city)

  PropertyManager.show_properties(results)
end
# =========================
# BUSCAR PRECIO
# =========================

def search_price do

  min =
    IO.gets("Precio mínimo: ")
    |> String.trim()
    |> String.to_integer()

  max =
    IO.gets("Precio máximo: ")
    |> String.trim()
    |> String.to_integer()

  results =
    PropertyManager.search_by_price(min, max)

  PropertyManager.show_properties(results)
end

end
