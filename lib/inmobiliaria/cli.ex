defmodule Inmobiliaria.CLI do

  alias Inmobiliaria.Users.UserManager
  alias Inmobiliaria.Property.PropertyManager
  alias Inmobiliaria.Property.Property
  alias Inmobiliaria.Messages.MessageManager
  alias Inmobiliaria.Operations.OperationLogger
  alias Inmobiliaria.Session.SessionManager

  # =========================
  # START
  # =========================

  def start do
    IO.puts("=== INMOBILIARIA ===")

    menu()
  end

  # =========================
  # MENU
  # =========================

  def menu do

    IO.puts("""

    ====== INMOBILIARIA ======

    1. Connect
    2. Logout

    3. Publicar propiedad
    4. Listar propiedades

    5. Comprar propiedad
    6. Arrendar propiedad

    7. Enviar mensaje
    8. Ver mensajes

    9. Ver historial
    10. Ver ranking

    11. Buscar por tipo
    12. Buscar por ciudad
    13. Buscar por precio

    14. Simular concurrencia
    15. Salir

    """)

    opcion =
      IO.gets("Seleccione: ")
      |> String.trim()

    case opcion do

      # =========================
      # LOGIN
      # =========================

      "1" ->
        connect()
        menu()

      # =========================
      # LOGOUT
      # =========================

      "2" ->
        SessionManager.logout()
        IO.puts("Sesión cerrada")
        menu()

      # =========================
      # PUBLICAR
      # =========================

      "3" ->
        publish_property()
        menu()

      # =========================
      # LISTAR
      # =========================

      "4" ->
        list_properties()
        menu()

      # =========================
      # COMPRAR
      # =========================

      "5" ->
        buy_property()
        menu()

      # =========================
      # ARRENDAR
      # =========================

      "6" ->
        rent_property()
        menu()

      # =========================
      # MENSAJES
      # =========================

      "7" ->
        send_message_cli()
        menu()

      "8" ->
        view_messages()
        menu()

      # =========================
      # HISTORIAL
      # =========================

      "9" ->
        show_history()
        menu()

      # =========================
      # RANKING
      # =========================

      "10" ->
        show_ranking()
        menu()

      # =========================
      # BÚSQUEDAS
      # =========================

      "11" ->
        search_type()
        menu()

      "12" ->
        search_city()
        menu()

      "13" ->
        search_price()
        menu()

      # =========================
      # CONCURRENCIA
      # =========================

      "14" ->
        simulate_buy()
        menu()

      # =========================
      # SALIR
      # =========================

      "15" ->
        IO.puts("Saliendo...")

      _ ->
        IO.puts("Opción inválida")
        menu()
    end
  end

  # =========================
  # CONNECT
  # =========================

  def connect do

    username =
      IO.gets("Usuario: ")
      |> String.trim()

    password =
      IO.gets("Password: ")
      |> String.trim()

    role =
      IO.gets("Rol: ")
      |> String.trim()

    case UserManager.login(username, password) do

      {:ok, user} ->

        SessionManager.login(
          user.username,
          user.role
        )

        IO.puts("Login exitoso")

      {:error, _} ->

        UserManager.register(
          username,
          password,
          role
        )

        SessionManager.login(username, role)

        IO.puts("Usuario registrado")
    end
  end

  # =========================
  # PUBLICAR
  # =========================

  def publish_property do

    user =
      SessionManager.current_user()

    cond do

      user == %{} ->

        IO.puts("Debe iniciar sesión")

      user.role not in ["vendedor", "arrendador"] ->

        IO.puts("No tiene permisos")

      true ->

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

        {:ok, _pid} =

          PropertyManager.create_property(%{
            id: id,
            type: type,
            modality: modality,
            city: city,
            price: price,
            owner: user.username,
            status: :available
          })

        IO.puts("Propiedad registrada")
    end
  end

  # =========================
  # LISTAR
  # =========================

  def list_properties do

    properties =
      PropertyManager.list_properties()

    Enum.each(properties, fn p ->
      IO.puts(p)
    end)
  end

  # =========================
  # COMPRAR
  # =========================

  def buy_property do

    user =
      SessionManager.current_user()

    cond do

      user == %{} ->

        IO.puts("Debe iniciar sesión")

      user.role != "cliente" ->

        IO.puts("Solo clientes pueden comprar")

      true ->

        property_id =
          IO.gets("ID propiedad: ")
          |> String.trim()

        result =
          Property.buy(
            property_id,
            user.username
          )

        IO.inspect(result)
    end
  end

  # =========================
  # ARRENDAR
  # =========================

  def rent_property do

    user =
      SessionManager.current_user()

    cond do

      user == %{} ->

        IO.puts("Debe iniciar sesión")

      user.role != "cliente" ->

        IO.puts("Solo clientes pueden arrendar")

      true ->

        property_id =
          IO.gets("ID propiedad: ")
          |> String.trim()

        result =
          Property.rent(
            property_id,
            user.username
          )

        IO.inspect(result)
    end
  end

  # =========================
  # SIMULAR COMPRA
  # =========================

  def simulate_buy do

    PropertyManager.create_property(%{
      id: "prop_test",
      type: "casa",
      modality: "venta",
      city: "Armenia",
      price: 100_000,
      owner: "Carlos",
      status: :available
    })

    task1 =

      Task.async(fn ->
        Property.buy("prop_test", "Ana")
      end)

    task2 =

      Task.async(fn ->
        Property.buy("prop_test", "Juan")
      end)

    IO.inspect(Task.await(task1))
    IO.inspect(Task.await(task2))

    IO.inspect(
      Property.get_info("prop_test")
    )
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

      IO.puts(
        "#{user.username} | #{user.role} | #{user.points} puntos"
      )
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
