defmodule InmobiliariaWeb.ChatLive do
  use InmobiliariaWeb, :live_view

  alias Inmobiliaria.Messages.MessageManager
  alias Inmobiliaria.Property.PropertyManager

  def mount(params, _session, socket) do
    username = Map.get(params, "user", "invitado")
    role = Map.get(params, "role", "cliente")
    property_id = Map.get(params, "property", nil)
    owner = Map.get(params, "owner", nil)

    properties =
      case role do
        r when r in ["vendedor", "arrendador"] ->
          PropertyManager.search_by_owner(username)
        _ ->
          PropertyManager.available_properties()
      end

    # Suscribirse a todos los canales de propiedades relevantes
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "user:#{username}")
      Enum.each(properties, fn p ->
        Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "property:#{p.id}")
      end)
    end

    {selected_property, selected_owner, messages} =
      if property_id do
        msgs = load_messages(property_id)
        {property_id, owner, msgs}
      else
        case properties do
          [first | _] ->
            msgs = load_messages(first.id)
            {first.id, first.owner, msgs}
          [] ->
            {nil, nil, []}
        end
      end

    # Contar mensajes no leídos por propiedad
    unread =
      properties
      |> Enum.map(fn p ->
        count = length(load_messages(p.id))
        {p.id, count}
      end)
      |> Map.new()

    {:ok,
     assign(socket,
       username: username,
       role: role,
       properties: properties,
       selected_property: selected_property,
       selected_owner: selected_owner,
       messages: messages,
       new_message: "",
       unread: unread,
       last_counts: unread
     )}
  end

  def handle_event("select_property", %{"property_id" => prop_id}, socket) do
    all_props = PropertyManager.list_properties()
    owner =
      case Enum.find(all_props, &(&1.id == prop_id)) do
        nil -> nil
        p -> p.owner
      end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "property:#{prop_id}")
    end

    messages = load_messages(prop_id)

    # Marcar como leído
    unread = Map.put(socket.assigns.unread, prop_id, length(messages))

    {:noreply,
     assign(socket,
       selected_property: prop_id,
       selected_owner: owner,
       messages: messages,
       unread: unread
     )}
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    {:noreply, assign(socket, new_message: msg)}
  end

  def handle_event("send_message", %{"message" => msg}, socket) do
    username = socket.assigns.username
    property_id = socket.assigns.selected_property
    owner = socket.assigns.selected_owner

    if property_id && String.trim(msg) != "" do
      MessageManager.send_message(property_id, username, owner, msg)

      message = %{
        date: DateTime.utc_now() |> DateTime.to_string(),
        property_id: property_id,
        client: username,
        owner: owner,
        message: String.trim(msg)
      }

      Phoenix.PubSub.broadcast(
        Inmobiliaria.PubSub,
        "property:#{property_id}",
        {:new_message, message}
      )

      messages = socket.assigns.messages ++ [message]
      {:noreply,
       socket
       |> assign(messages: messages, new_message: "")
       |> push_event("scroll_bottom", %{})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_message, message}, socket) do
    messages = socket.assigns.messages
    already_exists = Enum.any?(messages, fn m ->
      m.date == message.date && m.client == message.client
    end)

    if already_exists do
      {:noreply, socket}
    else
      new_messages = messages ++ [message]

      # Notificar si el mensaje es de otra propiedad
      unread =
        if message.property_id != socket.assigns.selected_property do
          current = Map.get(socket.assigns.unread, message.property_id, 0)
          Map.put(socket.assigns.unread, message.property_id, current + 1)
        else
          socket.assigns.unread
        end

      {:noreply,
       socket
       |> assign(messages: new_messages, unread: unread)
       |> push_event("scroll_bottom", %{})}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="min-height:100vh; background:#f0f2f5; font-family:sans-serif; display:flex; flex-direction:column;">

      <nav style="background:#1a1a2e; padding:1rem 2rem; display:flex; justify-content:space-between; align-items:center;">
        <span style="color:white; font-size:1.25rem; font-weight:700;">🏠 Inmobiliaria</span>
        <div style="display:flex; gap:1rem; align-items:center;">
          <a href={"/dashboard?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Dashboard</a>
          <a href={"/properties?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Propiedades</a>
          <a href="/" style="color:#f87171; text-decoration:none; font-weight:500;">Salir</a>
        </div>
      </nav>

      <div style="display:flex; flex:1; max-width:1200px; margin:2rem auto; width:100%; gap:1rem; padding:0 2rem; box-sizing:border-box;">

        <!-- PANEL IZQUIERDO -->
        <div style="width:280px; flex-shrink:0;">
          <div style="background:white; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); overflow:hidden;">
            <div style="padding:1rem 1.25rem; background:#4f46e5; color:white;">
              <h3 style="margin:0; font-size:1rem;">💬 Conversaciones</h3>
              <p style="margin:0.25rem 0 0; font-size:0.8rem; opacity:0.8;"><%= @username %> · <%= @role %></p>
            </div>

            <div style="padding:0.75rem;">
              <%= if Enum.empty?(@properties) do %>
                <p style="color:#999; font-size:0.875rem; padding:0.5rem;">Sin propiedades disponibles</p>
              <% else %>
                <%= for p <- @properties do %>
                  <%
                    saved = Map.get(@unread, p.id, 0)
                    is_selected = @selected_property == p.id
                    has_new = !is_selected && saved > 0
                  %>
                  <button
                    phx-click="select_property"
                    phx-value-property_id={p.id}
                    style={"width:100%; text-align:left; padding:0.75rem; border:none; border-radius:8px; cursor:pointer; margin-bottom:0.25rem; background:#{if is_selected, do: "#e0e7ff", else: "#f9fafb"}; border-left:3px solid #{if is_selected, do: "#4f46e5", else: "transparent"};"}>
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                      <div style="font-weight:600; font-size:0.875rem; color:#1a1a2e;"><%= p.type %> - <%= p.city %></div>
                      <%= if has_new do %>
                        <span style="background:#dc2626; color:white; font-size:0.7rem; padding:0.1rem 0.4rem; border-radius:999px; font-weight:700;">
                          nuevo
                        </span>
                      <% end %>
                    </div>
                    <div style="font-size:0.75rem; color:#888; margin-top:0.1rem;">🔑 <%= p.id %> · <%= p.modality %></div>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <!-- PANEL DERECHO -->
        <div style="flex:1; display:flex; flex-direction:column;">
          <%= if @selected_property do %>
            <div style="background:white; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); display:flex; flex-direction:column; height:600px;">

              <div style="padding:1rem 1.25rem; border-bottom:1px solid #f0f0f0; display:flex; align-items:center; gap:0.75rem;">
                <div style="width:40px; height:40px; background:#e0e7ff; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:1.25rem;">🏠</div>
                <div>
                  <div style="font-weight:700; color:#1a1a2e;">Propiedad <%= @selected_property %></div>
                  <div style="font-size:0.8rem; color:#888;">Propietario: <%= @selected_owner %></div>
                </div>
              </div>

              <div
                id="messages"
                phx-hook="ScrollBottom"
                style="flex:1; overflow-y:auto; padding:1rem; display:flex; flex-direction:column; gap:0.75rem;">
                <%= if Enum.empty?(@messages) do %>
                  <div style="text-align:center; color:#999; margin-top:2rem;">
                    No hay mensajes aún. ¡Sé el primero en escribir!
                  </div>
                <% else %>
                  <%= for msg <- @messages do %>
                    <% is_mine = msg.client == @username %>
                    <div style={"display:flex; justify-content:#{if is_mine, do: "flex-end", else: "flex-start"};"}>
                      <div style={"max-width:70%; padding:0.75rem 1rem; border-radius:#{if is_mine, do: "12px 12px 0 12px", else: "12px 12px 12px 0"}; background:#{if is_mine, do: "#4f46e5", else: "#f3f4f6"}; color:#{if is_mine, do: "white", else: "#1a1a2e"};"}>
                        <%= if !is_mine do %>
                          <div style="font-size:0.75rem; font-weight:600; margin-bottom:0.25rem; color:#4f46e5;"><%= msg.client %></div>
                        <% end %>
                        <div><%= msg.message %></div>
                        <div style="font-size:0.7rem; margin-top:0.25rem; opacity:0.7; text-align:right;">
                          <%= String.slice(msg.date, 11, 5) %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>

              <div style="padding:1rem; border-top:1px solid #f0f0f0;">
                <form phx-submit="send_message" style="display:flex; gap:0.5rem;">
                  <input
                    type="text"
                    name="message"
                    value={@new_message}
                    phx-change="update_message"
                    placeholder="Escribe un mensaje..."
                    style="flex:1; padding:0.75rem; border:1px solid #ddd; border-radius:8px; font-size:0.9rem; outline:none;"
                    autocomplete="off"/>
                  <button type="submit"
                    style="padding:0.75rem 1.25rem; background:#4f46e5; color:white; border:none; border-radius:8px; font-weight:600; cursor:pointer;">
                    Enviar
                  </button>
                </form>
              </div>

            </div>
          <% else %>
            <div style="background:white; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); padding:3rem; text-align:center; color:#999;">
              <div style="font-size:3rem; margin-bottom:1rem;">💬</div>
              <p>Selecciona una propiedad para iniciar una conversación</p>
            </div>
          <% end %>
        </div>

      </div>
    </div>
    """
  end

  defp load_messages(property_id) do
    MessageManager.get_property_messages(property_id)
    |> Enum.map(fn line ->
      case String.split(line, ";") do
        [date, prop_id, client, owner, message] ->
          %{date: date, property_id: prop_id, client: client, owner: owner, message: message}
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
end
