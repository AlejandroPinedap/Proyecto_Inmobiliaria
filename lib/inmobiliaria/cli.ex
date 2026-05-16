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

    IO.puts("""
    ==========================
        SISTEMA INMOBILIARIA
    ==========================
    """)

    menu()
  end

  # =========================
  # MENU
  # =========================

  def menu do

    IO.puts("""

    ========= MENÚ =========

    1. Login
    2. Registrar usuario
    3. Logout

    4. Publicar propiedad
    5. Listar propiedades
    6. Ver disponibles

    7. Comprar propiedad
    8. Arrendar propiedad

    9. Enviar mensaje
    10. Ver mensajes

    11. Ver historial
    12. Ver ranking

    13. Buscar por tipo
    14. Buscar por ciudad
    15. Buscar por precio
    16. Buscar por modalidad

    17. Ver sesión
    18. Simular concurrencia

    19. Salir

    ========================

    """)

    option =
      IO.gets("Seleccione una opción: ")
      |> String.trim()

    case option do

      # =========================
      # LOGIN
      # =========================

      "1" ->
        connect()
        menu()

      # =========================
      # REGISTER
      # =========================

      "2" ->
        register_user()
        menu()

      # =========================
      # LOGOUT
      # =========================

      "3" ->
        SessionManager.logout()
        IO.puts("Sesión cerrada")
        menu()

      # =========================
      # PUBLICAR
      # =========================

      "4" ->
        publish_property()
        menu()

      # =========================
      # LISTAR
      # =========================

      "5" ->
        list_properties()
        menu()

      # =========================
      # DISPONIBLES
      # =========================

      "6" ->
        available_properties()
        menu()

      # =========================
      # COMPRAR
      # =========================

      "7" ->
        buy_property()
        menu()

      # =========================
      # ARRENDAR
      # =========================

      "8" ->
        rent_property()
        menu()

      # =========================
      # MENSAJES
      # =========================

      "9" ->
        send_message_cli()
        menu()

      "10" ->
        view_messages()
        menu()

      # =========================
      # HISTORIAL
      # =========================

      "11" ->
        show_history()
        menu()

      # =========================
      # RANKING
      # =========================

      "12" ->
        show_ranking()
        menu()

      # =========================
      # BÚSQUEDAS
      # =========================

      "13" ->
        search_type()
        menu()

      "14" ->
        search_city()
        menu()

      "15" ->
        search_price()
        menu()

      "16" ->
        search_modality()
        menu()

      # =========================
      # SESIÓN
      # =========================

      "17" ->
        show_session()
        menu()

      # =========================
      # CONCURRENCIA
      # =========================

      "18" ->
        simulate_buy()
        menu()

      # =========================
      # SALIR
      # =========================

      "19" ->
        IO.puts("Saliendo del sistema...")

      _ ->
        IO.puts("Opción inválida")
        menu()
    end
  end

  # =========================
  # LOGIN
  # =========================

  def connect do

    username =
      IO.gets("Usuario: ")
      |> String.trim()

    password =
      IO.gets("Password: ")
      |> String.trim()

    case UserManager.login(username, password) do

      {:ok, user} ->

        SessionManager.login(
          user.username,
          user.role
        )

        IO.puts("Login exitoso")

      {:error, message} ->

        IO.puts(message)
    end
  end

  # =========================
  # REGISTER
  # =========================

  def register_user do

    username =
      IO.gets("Usuario: ")
      |> String.trim()

    password =
      IO.gets("Password: ")
      |> String.trim()

    role =
      IO.gets("Rol (cliente/vendedor/arrendador): ")
      |> String.trim()

    case UserManager.register(username, password, role) do

      {:ok, _user} ->
        IO.puts("Usuario registrado")

      {:error, message} ->
        IO.puts(message)
    end
  end

  # =========================
  # PUBLICAR PROPIEDAD
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
  # LISTAR PROPIEDADES
  # =========================

  def list_properties do

    properties =
      PropertyManager.list_properties()

    PropertyManager.show_properties(properties)
  end

  # =========================
  # VER DISPONIBLES
  # =========================

  def available_properties do

    properties =
      PropertyManager.available_properties()

    PropertyManager.show_properties(properties)
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
  # ENVIAR MENSAJE
  # =========================

  def send_message_cli do

    user =
      SessionManager.current_user()

    if user == %{} do

      IO.puts("Debe iniciar sesión")

    else

      property_id =
        IO.gets("ID propiedad: ")
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
          user.username,
          owner,
          message
        )

      IO.inspect(response)
    end
  end

  # =========================
  # VER MENSAJES
  # =========================

  def view_messages do

    user =
      SessionManager.current_user()

    if user == %{} do

      IO.puts("Debe iniciar sesión")

    else

      messages =
        MessageManager.get_owner_messages(
          user.username
        )

      MessageManager.show_messages(messages)
    end
  end

  # =========================
  # HISTORIAL
  # =========================

  def show_history do

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

  # =========================
  # BUSCAR MODALIDAD
  # =========================

  def search_modality do

    modality =
      IO.gets("Modalidad: ")
      |> String.trim()

    results =
      PropertyManager.search_by_modality(modality)

    PropertyManager.show_properties(results)
  end

  # =========================
  # VER SESIÓN
  # =========================

  def show_session do

    user =
      SessionManager.current_user()

    if user == %{} do

      IO.puts("No hay sesión activa")

    else

      IO.puts("""
      ===== SESIÓN =====

      Usuario: #{user.username}
      Rol: #{user.role}

      ==================
      """)
    end
  end

  # =========================
  # SIMULAR CONCURRENCIA
  # =========================

  def simulate_buy do

    properties =
      PropertyManager.list_properties()

    exists? =

      Enum.any?(properties, fn p ->
        p.id == "prop_test"
      end)

    unless exists? do

      PropertyManager.create_property(%{
        id: "prop_test",
        type: "casa",
        modality: "venta",
        city: "Armenia",
        price: 100_000,
        owner: "Carlos",
        status: :available
      })
    end

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
end
