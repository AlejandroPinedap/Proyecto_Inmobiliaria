defmodule Inmobiliaria.Server do
  alias Inmobiliaria.Users.UserManager
  alias Inmobiliaria.Property.Property
  alias Inmobiliaria.Property.PropertyManager
  alias Inmobiliaria.Messages.MessageManager
  alias Inmobiliaria.ClientRegistry

  @port 4040

  def start do
    {:ok, socket} =
      :gen_tcp.listen(@port, [
        :binary,
        packet: :line,
        active: false,
        reuseaddr: true
      ])
    IO.puts("Servidor escuchando en puerto #{@port}...")
    listen_loop(socket)
  end

  defp listen_loop(server_socket) do
    {:ok, client_socket} = :gen_tcp.accept(server_socket)
    :inet.setopts(client_socket, active: true)
    pid = spawn(fn -> handle_client(client_socket, %{}) end)
    :gen_tcp.controlling_process(client_socket, pid)
    listen_loop(server_socket)
  end

  defp handle_client(socket, session) do
    show_welcome(socket)
    client_loop(socket, session)
  end

  defp show_welcome(socket) do
    send_line(socket, "\r\n=== INMOBILIARIA VIRTUAL ===\r\n")
    send_line(socket, "  1. Iniciar sesion")
    send_line(socket, "  2. Registrarse")
    send_line(socket, "  0. Salir\r\n")
    send_line(socket, "Seleccione una opcion:")
  end

  defp client_loop(socket, session) do
    receive do
      {:tcp, ^socket, data} ->
        input = String.trim(data)
        {response, new_session} = handle_input(input, session)
        send_line(socket, response)
        client_loop(socket, new_session)

      {:chat_message, from, message} ->
        send_line(socket, "\r\n[CHAT] #{from}: #{message}")
        client_loop(socket, session)

      {:tcp_closed, ^socket} ->
        cleanup(session)
        :gen_tcp.close(socket)

      {:tcp_error, ^socket, _reason} ->
        cleanup(session)
        :gen_tcp.close(socket)
    end
  end

  defp cleanup(session) do
    if Map.get(session, :username) do
      ClientRegistry.unregister(session.username)
      UserManager.disconnect(session.username)
    end
  end

  defp send_line(socket, message) do
    :gen_tcp.send(socket, message <> "\r\n")
  end

  defp handle_input(input, session) do
    case Map.get(session, :context) do
      nil                  -> handle_welcome_menu(input, session)
      :registering_user    -> handle_register_user(input, session)
      :registering_pass    -> handle_register_pass(input, session)
      :registering_role    -> handle_register_role(input, session)
      :login_user          -> handle_login_user(input, session)
      :login_pass          -> handle_login_pass(input, session)
      :main_menu           -> handle_main_menu(input, session)
      :publishing_id       -> handle_publish_id(input, session)
      :publishing_type     -> handle_publish_type(input, session)
      :publishing_modality -> handle_publish_modality(input, session)
      :publishing_city     -> handle_publish_city(input, session)
      :publishing_price    -> handle_publish_price(input, session)
      :buying_id           -> handle_buy_id(input, session)
      :renting_id          -> handle_rent_id(input, session)
      :messaging_id        -> handle_message_id(input, session)
      :messaging_text      -> handle_message_text(input, session)
      :chatting_user       -> handle_chat_user(input, session)
      :chatting_text       -> handle_chat_text(input, session)
      :filter_menu         -> handle_filter_option(input, session)
      :filter_type         -> handle_filter_by_type(input, session)
      :filter_city         -> handle_filter_by_city(input, session)
      :filter_price_min    -> handle_filter_price_min(input, session)
      :filter_price_max    -> handle_filter_price_max(input, session)
    end
  end

  defp handle_welcome_menu(option, session) do
    case option do
      "1" -> {"Ingresa tu usuario:", Map.put(session, :context, :login_user)}
      "2" -> {"Ingresa tu usuario:", Map.put(session, :context, :registering_user)}
      "0" -> {"Hasta luego!", session}
      _   -> {"[ERROR] Opcion invalida. Elige 1, 2 o 0:", session}
    end
  end

  defp handle_register_user(username, session) do
    users = UserManager.load_users()
    exists = Enum.any?(users, fn u -> u.username == username end)
    if exists do
      {"[ERROR] El usuario #{username} ya existe. Intenta con otro nombre:", session}
    else
      new_session = session |> Map.put(:context, :registering_pass) |> Map.put(:reg_username, username)
      {"Ingresa tu password:", new_session}
    end
  end

  defp handle_register_pass(password, session) do
    new_session = session |> Map.put(:context, :registering_role) |> Map.put(:reg_password, password)
    {"Selecciona tu rol:\r\n  1. Cliente\r\n  2. Vendedor\r\n  3. Arrendador", new_session}
  end

  defp handle_register_role(option, session) do
    role = case option do
      "1" -> "cliente"
      "2" -> "vendedor"
      "3" -> "arrendador"
      _   -> nil
    end
    if role == nil do
      {"[ERROR] Opcion invalida. Elige 1, 2 o 3:", session}
    else
      username = Map.get(session, :reg_username)
      password = Map.get(session, :reg_password)
      UserManager.register(username, password, role)
      ClientRegistry.register(username, self())
      new_session = %{username: username, role: role, context: :main_menu}
      {"[OK] Registrado exitosamente!\r\n" <> show_main_menu(role), new_session}
    end
  end

  defp handle_login_user(username, session) do
    new_session = session |> Map.put(:context, :login_pass) |> Map.put(:login_username, username)
    {"Ingresa tu password:", new_session}
  end

  defp handle_login_pass(password, session) do
    username = Map.get(session, :login_username)
    users = UserManager.load_users()
    exists = Enum.any?(users, fn u -> u.username == username end)
    cond do
      not exists ->
        {"[ERROR] Usuario no encontrado. Registrate primero (opcion 2):", %{context: nil}}
      true ->
        case UserManager.login(username, password) do
          {:ok, user} ->
            ClientRegistry.register(username, self())
            new_session = %{username: user.username, role: user.role, context: :main_menu}
            {"[OK] Bienvenido/a #{username}!\r\n" <> show_main_menu(user.role), new_session}
          {:error, _} ->
            {"[ERROR] Password incorrecta. Intenta de nuevo:", session}
        end
    end
  end

  defp show_main_menu(role) do
    case role do
      "cliente" ->
        "\r\n=== MENU CLIENTE ===\r\n" <>
        "  1. Ver propiedades\r\n" <>
        "  2. Comprar propiedad\r\n" <>
        "  3. Arrendar propiedad\r\n" <>
        "  4. Enviar mensaje a propietario\r\n" <>
        "  5. Ver mis mensajes\r\n" <>
        "  6. Chat con usuario\r\n" <>
        "  7. Mi puntaje\r\n" <>
        "  8. Ranking\r\n" <>
        "  9. Historial\r\n" <>
        "  0. Cerrar sesion\r\n"
      role when role in ["vendedor", "arrendador"] ->
        "\r\n=== MENU #{String.upcase(role)} ===\r\n" <>
        "  1. Publicar propiedad\r\n" <>
        "  2. Ver mis propiedades\r\n" <>
        "  3. Ver mensajes recibidos\r\n" <>
        "  4. Chat con usuario\r\n" <>
        "  5. Mi puntaje\r\n" <>
        "  6. Ranking\r\n" <>
        "  7. Historial\r\n" <>
        "  0. Cerrar sesion\r\n"
    end
  end

  defp handle_main_menu(option, session) do
    case Map.get(session, :role) do
      "cliente"    -> handle_client_menu(option, session)
      "vendedor"   -> handle_owner_menu(option, session)
      "arrendador" -> handle_owner_menu(option, session)
    end
  end

  defp handle_client_menu(option, session) do
    case option do
      "1" -> show_properties_with_filter(session)
      "2" -> {"Ingresa el ID de la propiedad a comprar:", Map.put(session, :context, :buying_id)}
      "3" -> {"Ingresa el ID de la propiedad a arrendar:", Map.put(session, :context, :renting_id)}
      "4" -> {"Ingresa el ID de la propiedad:", Map.put(session, :context, :messaging_id)}
      "5" -> show_inbox(session)
      "6" -> {"Ingresa el usuario al que quieres escribir:", Map.put(session, :context, :chatting_user)}
      "7" -> show_score(session)
      "8" -> show_ranking(session)
      "9" -> show_history(session)
      "0" -> logout(session)
      _   -> {"[ERROR] Opcion invalida\r\n" <> show_main_menu(session.role), session}
    end
  end

  defp handle_owner_menu(option, session) do
    case option do
      "1" -> {"Ingresa el ID de la propiedad:", Map.put(session, :context, :publishing_id)}
      "2" -> show_my_properties(session)
      "3" -> show_inbox(session)
      "4" -> {"Ingresa el usuario al que quieres escribir:", Map.put(session, :context, :chatting_user)}
      "5" -> show_score(session)
      "6" -> show_ranking(session)
      "7" -> show_history(session)
      "0" -> logout(session)
      _   -> {"[ERROR] Opcion invalida\r\n" <> show_main_menu(session.role), session}
    end
  end

  defp handle_publish_id(id, session) do
    properties = PropertyManager.list_properties()
    if Enum.any?(properties, fn p -> p.id == id end) do
      {"[ERROR] Ya existe una propiedad con ese ID. Ingresa otro ID:", session}
    else
      new_session = session |> Map.put(:context, :publishing_type) |> Map.put(:pub_id, id)
      {"Tipo (casa, apartamento, oficina, lote):", new_session}
    end
  end

  defp handle_publish_type(type, session) do
    valid = ["casa", "apartamento", "oficina", "lote"]
    if String.downcase(type) not in valid do
      {"[ERROR] Tipo invalido. Elige: casa, apartamento, oficina, lote:", session}
    else
      new_session = session |> Map.put(:context, :publishing_modality) |> Map.put(:pub_type, String.downcase(type))
      {"Modalidad (venta / arriendo):", new_session}
    end
  end

  defp handle_publish_modality(modality, session) do
    clean = String.downcase(modality)
    if clean not in ["venta", "arriendo"] do
      {"[ERROR] Modalidad invalida. Elige venta o arriendo:", session}
    else
      ciudades = Inmobiliaria.Location.cargar_ubicaciones()
      new_session = session |> Map.put(:context, :publishing_city) |> Map.put(:pub_modality, clean)
      {"Ciudad (#{Enum.join(ciudades, ", ")}):", new_session}
    end
  end

  defp handle_publish_city(city, session) do
    if not Inmobiliaria.Location.valida?(city) do
      ciudades = Inmobiliaria.Location.cargar_ubicaciones()
      {"[ERROR] Ciudad invalida. Elige: #{Enum.join(ciudades, ", ")}:", session}
    else
      new_session = session |> Map.put(:context, :publishing_price) |> Map.put(:pub_city, city)
      {"Precio:", new_session}
    end
  end

  defp handle_publish_price(price_str, session) do
    case Integer.parse(String.trim(price_str)) do
      :error ->
        {"[ERROR] Precio invalido. Ingresa un numero:", session}
      {price, _} ->
        data = %{
          id:       Map.get(session, :pub_id),
          type:     Map.get(session, :pub_type),
          modality: Map.get(session, :pub_modality),
          city:     Map.get(session, :pub_city),
          price:    price,
          owner:    Map.get(session, :username),
          status:   :available
        }
        PropertyManager.create_property(data)
        clean_session =
          session
          |> Map.delete(:pub_id)
          |> Map.delete(:pub_type)
          |> Map.delete(:pub_modality)
          |> Map.delete(:pub_city)
          |> Map.put(:context, :main_menu)
        {"[OK] Propiedad publicada!\r\n" <> show_main_menu(session.role), clean_session}
    end
  end

  defp handle_buy_id(property_id, session) do
    username = Map.get(session, :username)
    new_session = Map.put(session, :context, :main_menu)
    case Property.buy(property_id, username) do
      {:ok, msg}    -> {"[OK] #{msg} | +10 pts\r\n" <> show_main_menu(session.role), new_session}
      {:error, msg} -> {"[ERROR] #{msg}\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp handle_rent_id(property_id, session) do
    username = Map.get(session, :username)
    new_session = Map.put(session, :context, :main_menu)
    case Property.rent(property_id, username) do
      {:ok, msg}    -> {"[OK] #{msg} | +8 pts\r\n" <> show_main_menu(session.role), new_session}
      {:error, msg} -> {"[ERROR] #{msg}\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp handle_message_id(property_id, session) do
    properties = PropertyManager.list_properties()
    case Enum.find(properties, fn p -> p.id == property_id end) do
      nil ->
        new_session = Map.put(session, :context, :main_menu)
        {"[ERROR] Propiedad no encontrada\r\n" <> show_main_menu(session.role), new_session}
      property ->
        new_session =
          session
          |> Map.put(:context, :messaging_text)
          |> Map.put(:msg_property_id, property_id)
          |> Map.put(:msg_owner, property.owner)
        {"Escribe tu mensaje para #{property.owner}:", new_session}
    end
  end

  defp handle_message_text(text, session) do
    username    = Map.get(session, :username)
    property_id = Map.get(session, :msg_property_id)
    owner       = Map.get(session, :msg_owner)
    MessageManager.send_message(property_id, username, owner, username, text)
    clean_session =
      session
      |> Map.delete(:msg_property_id)
      |> Map.delete(:msg_owner)
      |> Map.put(:context, :main_menu)
    {"[OK] Mensaje enviado a #{owner}\r\n" <> show_main_menu(session.role), clean_session}
  end

  defp handle_chat_user(target, session) do
    case ClientRegistry.lookup(target) do
      {:error, _} ->
        new_session = Map.put(session, :context, :main_menu)
        {"[ERROR] #{target} no esta conectado\r\n" <> show_main_menu(session.role), new_session}
      {:ok, _} ->
        new_session = session |> Map.put(:context, :chatting_text) |> Map.put(:chat_target, target)
        {"Escribe tu mensaje para #{target}:", new_session}
    end
  end

  defp handle_chat_text(text, session) do
    from   = Map.get(session, :username)
    target = Map.get(session, :chat_target)
    case ClientRegistry.lookup(target) do
      {:ok, pid} ->
        send(pid, {:chat_message, from, text})
        clean_session = session |> Map.delete(:chat_target) |> Map.put(:context, :main_menu)
        {"[CHAT] -> #{target}: #{text}\r\n" <> show_main_menu(session.role), clean_session}
      {:error, _} ->
        new_session = Map.put(session, :context, :main_menu)
        {"[ERROR] #{target} se desconecto\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp show_properties_with_filter(session) do
    properties = PropertyManager.list_properties()
    if Enum.empty?(properties) do
      {"No hay propiedades registradas\r\n" <> show_main_menu(session.role), session}
    else
      table = format_properties_table(properties)
      menu =
        "\r\nFiltrar lista:\r\n" <>
        "  1. Por tipo\r\n" <>
        "  2. Por ciudad\r\n" <>
        "  3. Por precio\r\n" <>
        "  4. Solo disponibles\r\n" <>
        "  0. Sin filtro\r\n"
      {table <> menu, Map.put(session, :context, :filter_menu)}
    end
  end

  defp show_my_properties(session) do
    username = Map.get(session, :username)
    results = PropertyManager.search_by_owner(username)
    new_session = Map.put(session, :context, :main_menu)
    if Enum.empty?(results) do
      {"No tienes propiedades publicadas\r\n" <> show_main_menu(session.role), new_session}
    else
      {format_properties_table(results) <> "\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp show_inbox(session) do
    username = Map.get(session, :username)
    messages = MessageManager.get_owner_messages(username)
    new_session = Map.put(session, :context, :main_menu)
    if Enum.empty?(messages) do
      {"No tienes mensajes nuevos\r\n" <> show_main_menu(session.role), new_session}
    else
      separator = "\r\n-----------------------------------------"
      header = separator <> "\r\n[MENSAJES] DE #{String.upcase(username)}" <> separator
      body = Enum.join(messages, "\r\n")
      {header <> "\r\n" <> body <> separator <> "\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp show_score(session) do
    username = Map.get(session, :username)
    new_session = Map.put(session, :context, :main_menu)
    case UserManager.get_score(username) do
      {:ok, score} -> {"[PTS] #{username}: #{score} puntos\r\n" <> show_main_menu(session.role), new_session}
      {:error, _}  -> {"[ERROR] Error consultando puntaje\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp show_ranking(session) do
    new_session = Map.put(session, :context, :main_menu)
    case UserManager.ranking() do
      [] ->
        {"No hay usuarios registrados\r\n" <> show_main_menu(session.role), new_session}
      ranking ->
        separator = "\r\n-----------------------------------------"
        header = separator <> "\r\n[RANKING] GLOBAL\r\n" <> " #    Usuario         Rol          Pts" <> separator
        rows =
          ranking
          |> Enum.with_index(1)
          |> Enum.map(fn {user, i} ->
            "#{String.pad_trailing("#{i}.", 5)} #{String.pad_trailing(user.username, 16)} #{String.pad_trailing(user.role, 12)} #{user.points} pts"
          end)
          |> Enum.join("\r\n")
        {header <> "\r\n" <> rows <> separator <> "\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp show_history(session) do
    new_session = Map.put(session, :context, :main_menu)
    if File.exists?("data/results.log") do
      content = File.read!("data/results.log")
      if String.trim(content) == "" do
        {"No hay operaciones registradas\r\n" <> show_main_menu(session.role), new_session}
      else
        separator = "\r\n-----------------------------------------"
        {separator <> "\r\n[HISTORIAL]\r\n" <> separator <> "\r\n" <> content <> "\r\n" <> show_main_menu(session.role), new_session}
      end
    else
      {"No hay historial\r\n" <> show_main_menu(session.role), new_session}
    end
  end

  defp logout(session) do
    username = Map.get(session, :username)
    ClientRegistry.unregister(username)
    UserManager.disconnect(username)
    welcome =
      "\r\n=== INMOBILIARIA VIRTUAL ===\r\n\r\n" <>
      "  1. Iniciar sesion\r\n" <>
      "  2. Registrarse\r\n" <>
      "  0. Salir\r\n\r\n" <>
      "Seleccione una opcion:"
    {"[OK] Hasta luego #{username}!\r\n" <> welcome, %{}}
  end

  defp handle_filter_option(option, session) do
    clean = Map.delete(session, :context)
    case String.trim(option) do
      "1" -> {"Tipo (casa, apartamento, oficina, lote):", Map.put(clean, :context, :filter_type)}
      "2" -> {"Ciudad:", Map.put(clean, :context, :filter_city)}
      "3" -> {"Precio minimo:", Map.put(clean, :context, :filter_price_min)}
      "4" ->
        results = PropertyManager.available_properties()
        ns = Map.put(clean, :context, :main_menu)
        if Enum.empty?(results) do
          {"No hay propiedades disponibles\r\n" <> show_main_menu(session.role), ns}
        else
          {format_properties_table(results) <> "\r\n" <> show_main_menu(session.role), ns}
        end
      "0" ->
        {show_main_menu(session.role), Map.put(clean, :context, :main_menu)}
      _ ->
        {"[ERROR] Opcion invalida. Elige 0-4:", Map.put(clean, :context, :filter_menu)}
    end
  end

  defp handle_filter_by_type(tipo, session) do
    ns = Map.put(session, :context, :main_menu)
    results = PropertyManager.search_by_type(String.trim(tipo))
    if Enum.empty?(results) do
      {"No hay propiedades de tipo #{tipo}\r\n" <> show_main_menu(session.role), ns}
    else
      {format_properties_table(results) <> "\r\n" <> show_main_menu(session.role), ns}
    end
  end

  defp handle_filter_by_city(ciudad, session) do
    ns = Map.put(session, :context, :main_menu)
    results = PropertyManager.search_by_city(String.trim(ciudad))
    if Enum.empty?(results) do
      {"No hay propiedades en #{ciudad}\r\n" <> show_main_menu(session.role), ns}
    else
      {format_properties_table(results) <> "\r\n" <> show_main_menu(session.role), ns}
    end
  end

  defp handle_filter_price_min(min_str, session) do
    clean = Map.delete(session, :context)
    case Integer.parse(String.trim(min_str)) do
      {min, _} ->
        {"Precio maximo:", clean |> Map.put(:context, :filter_price_max) |> Map.put(:price_min, min)}
      :error ->
        {"[ERROR] Precio invalido:", Map.put(clean, :context, :filter_price_min)}
    end
  end

  defp handle_filter_price_max(max_str, session) do
    min = Map.get(session, :price_min, 0)
    ns = session |> Map.delete(:context) |> Map.delete(:price_min) |> Map.put(:context, :main_menu)
    case Integer.parse(String.trim(max_str)) do
      {max, _} ->
        results = PropertyManager.search_by_price(min, max)
        if Enum.empty?(results) do
          {"No hay propiedades en ese rango\r\n" <> show_main_menu(session.role), ns}
        else
          {format_properties_table(results) <> "\r\n" <> show_main_menu(session.role), ns}
        end
      :error ->
        {"[ERROR] Precio invalido:", session |> Map.put(:context, :filter_price_max) |> Map.put(:price_min, min)}
    end
  end

  defp format_properties_table(properties) do
    separator = "\r\n------------------------------------------------------------------"
    header =
      separator <>
      "\r\n ID          | Tipo      | Modalidad | Ciudad    | Precio      | Estado     | Dueno" <>
      separator
    rows =
      properties
      |> Enum.map(fn p ->
        " #{String.pad_trailing(p.id, 10)} | #{String.pad_trailing(p.type, 9)} | #{String.pad_trailing(p.modality, 9)} | #{String.pad_trailing(p.city, 9)} | #{String.pad_trailing("$#{p.price}", 11)} | #{String.pad_trailing("#{p.status}", 10)} | #{p.owner}"
      end)
      |> Enum.join("\r\n")
    header <> "\r\n" <> rows <> separator
  end
end
