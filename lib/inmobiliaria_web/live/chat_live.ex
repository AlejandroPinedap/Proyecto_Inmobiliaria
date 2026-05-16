defmodule InmobiliariaWeb.ChatLive do
  use InmobiliariaWeb, :live_view

  alias Inmobiliaria.Messages.MessageManager
  alias Inmobiliaria.Property.PropertyManager

  # =====================================================================
  # MOUNT
  # =====================================================================

  def mount(params, _session, socket) do
    username = Map.get(params, "user", "invitado")
    role = Map.get(params, "role", "cliente")
    property_id = Map.get(params, "property", nil)
    owner_param = Map.get(params, "owner", nil)

    {conversations, properties_map} =
      case role do
        r when r in ["vendedor", "arrendador"] ->
          pairs = MessageManager.get_owner_conversations(username)
          all_props = PropertyManager.list_properties()
          props_map = Map.new(all_props, &{&1.id, &1})

          convs =
            Enum.map(pairs, fn {prop_id, client} ->
              prop =
                Map.get(props_map, prop_id, %{id: prop_id, type: "?", city: "?", modality: "?"})

              %{
                key: conv_key(prop_id, client, username),
                property_id: prop_id,
                client: client,
                owner: username,
                label: "#{prop.type} - #{prop.city}",
                sublabel: "Cliente: #{client}"
              }
            end)

          {convs, props_map}

        _ ->
          props = PropertyManager.available_properties()
          props_map = Map.new(props, &{&1.id, &1})

          convs =
            Enum.map(props, fn p ->
              %{
                key: conv_key(p.id, username, p.owner),
                property_id: p.id,
                client: username,
                owner: p.owner,
                label: "#{p.type} - #{p.city}",
                sublabel: "Propietario: #{p.owner}"
              }
            end)

          {convs, props_map}
      end

    selected =
      cond do
        property_id != nil and owner_param != nil ->
          Enum.find(conversations, fn c ->
            c.property_id == property_id and c.owner == owner_param
          end) ||
            %{
              key: conv_key(property_id, username, owner_param),
              property_id: property_id,
              client: username,
              owner: owner_param,
              label: label_for(properties_map, property_id),
              sublabel: "Propietario: #{owner_param}"
            }

        conversations != [] ->
          hd(conversations)

        true ->
          nil
      end

    conversations =
      if selected != nil and not Enum.any?(conversations, &(&1.key == selected.key)) do
        [selected | conversations]
      else
        conversations
      end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "user:#{username}")
      Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "notifications:#{username}")

      Enum.each(conversations, fn c ->
        Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "conv:#{c.key}")
      end)
    end

    # Al entrar al chat reseteamos el contador del navbar
    Inmobiliaria.NotificationManager.reset(username)

    messages =
      if selected, do: load_conv_messages(selected), else: []

    {:ok,
     assign(socket,
       username: username,
       role: role,
       conversations: conversations,
       selected: selected,
       messages: messages,
       new_message: "",
       unread: %{},
       unread_count: 0
     )}
  end

  # =====================================================================
  # EVENTOS
  # =====================================================================

  def handle_event("select_conv", %{"key" => key}, socket) do
    conv = Enum.find(socket.assigns.conversations, &(&1.key == key))

    if conv do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "conv:#{key}")
      end

      messages = load_conv_messages(conv)
      unread = Map.delete(socket.assigns.unread, key)

      {:noreply, assign(socket, selected: conv, messages: messages, unread: unread)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => msg}, socket) do
    {:noreply, assign(socket, new_message: msg)}
  end

  def handle_event("send_message", %{"message" => msg}, socket) do
    username = socket.assigns.username
    conv = socket.assigns.selected

    if conv && String.trim(msg) != "" do
      text = String.trim(msg)

      # Guardamos quién envió (sender) además del par client/owner
      MessageManager.send_message(conv.property_id, conv.client, conv.owner, username, text)

      message = %{
        date: DateTime.utc_now() |> DateTime.to_string(),
        property_id: conv.property_id,
        client: conv.client,
        owner: conv.owner,
        sender: username,
        message: text
      }

      Phoenix.PubSub.broadcast(
        Inmobiliaria.PubSub,
        "conv:#{conv.key}",
        {:new_message, message}
      )

      Phoenix.PubSub.broadcast(
        Inmobiliaria.PubSub,
        "user:#{conv.owner}",
        {:new_conversation, conv}
      )

      # Notificar al destinatario (quien NO está escribiendo)
      recipient = if username == conv.client, do: conv.owner, else: conv.client
      Inmobiliaria.NotificationManager.increment(recipient)

      messages = socket.assigns.messages ++ [message]

      {:noreply,
       socket
       |> assign(messages: messages, new_message: "")
       |> push_event("scroll_bottom", %{})}
    else
      {:noreply, socket}
    end
  end

  # =====================================================================
  # INFO (PubSub)
  # =====================================================================

  def handle_info({:new_notification, count}, socket) do
    {:noreply, assign(socket, unread_count: count)}
  end

  def handle_info({:new_message, message}, socket) do
    key = conv_key(message.property_id, message.client, message.owner)

    already =
      if socket.assigns.selected && socket.assigns.selected.key == key do
        Enum.any?(socket.assigns.messages, fn m ->
          m.date == message.date and m.sender == message.sender
        end)
      else
        false
      end

    if already do
      {:noreply, socket}
    else
      socket =
        if socket.assigns.selected && socket.assigns.selected.key == key do
          socket
          |> assign(messages: socket.assigns.messages ++ [message])
          |> push_event("scroll_bottom", %{})
        else
          unread = Map.update(socket.assigns.unread, key, 1, &(&1 + 1))
          assign(socket, unread: unread)
        end

      {:noreply, socket}
    end
  end

  def handle_info({:new_conversation, conv}, socket) do
    already = Enum.any?(socket.assigns.conversations, &(&1.key == conv.key))

    if already do
      {:noreply, socket}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "conv:#{conv.key}")
      end

      conversations = socket.assigns.conversations ++ [conv]
      unread = Map.put(socket.assigns.unread, conv.key, 1)

      {:noreply, assign(socket, conversations: conversations, unread: unread)}
    end
  end

  # =====================================================================
  # RENDER
  # =====================================================================

  def render(assigns) do
    ~H"""
    <div style="min-height:100vh; background:#f0f2f5; font-family:sans-serif; display:flex; flex-direction:column;">

      <nav style="background:#1a1a2e; padding:1rem 2rem; display:flex; justify-content:space-between; align-items:center;">
        <span style="color:white; font-size:1.25rem; font-weight:700;">🏠 Inmobiliaria</span>
        <div style="display:flex; gap:1rem; align-items:center;">
          <a href={"/dashboard?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Dashboard</a>
          <a href={"/properties?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Propiedades</a>
          <span style="color:white; font-weight:600; display:inline-flex; align-items:center; gap:0.3rem;">
            💬 Chat
            <%= if @unread_count > 0 do %>
              <span style="background:#dc2626; color:white; font-size:0.65rem; padding:0.1rem 0.4rem; border-radius:999px; font-weight:700; line-height:1.2;">
                <%= @unread_count %>
              </span>
            <% end %>
          </span>
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
              <%= if Enum.empty?(@conversations) do %>
                <p style="color:#999; font-size:0.875rem; padding:0.5rem;">
                  <%= if @role in ["vendedor", "arrendador"] do %>
                    Aún no tienes conversaciones. Los clientes te escribirán desde Propiedades.
                  <% else %>
                    No hay propiedades disponibles para contactar.
                  <% end %>
                </p>
              <% else %>
                <%= for conv <- @conversations do %>
                  <%
                    is_selected  = @selected && @selected.key == conv.key
                    unread_count = Map.get(@unread, conv.key, 0)
                  %>
                  <button
                    phx-click="select_conv"
                    phx-value-key={conv.key}
                    style={"width:100%; text-align:left; padding:0.75rem; border:none; border-radius:8px; cursor:pointer; margin-bottom:0.25rem;
                      background:#{if is_selected, do: "#e0e7ff", else: "#f9fafb"};
                      border-left:3px solid #{if is_selected, do: "#4f46e5", else: "transparent"};"}>
                    <div style="display:flex; justify-content:space-between; align-items:center;">
                      <div style="font-weight:600; font-size:0.875rem; color:#1a1a2e; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:170px;">
                        <%= conv.label %>
                      </div>
                      <%= if unread_count > 0 do %>
                        <span style="background:#dc2626; color:white; font-size:0.7rem; padding:0.1rem 0.45rem; border-radius:999px; font-weight:700; flex-shrink:0;">
                          <%= unread_count %>
                        </span>
                      <% end %>
                    </div>
                    <div style="font-size:0.75rem; color:#888; margin-top:0.15rem;">
                      <%= conv.sublabel %>
                    </div>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>

        <!-- PANEL DERECHO -->
        <div style="flex:1; display:flex; flex-direction:column;">
          <%= if @selected do %>
            <div style="background:white; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); display:flex; flex-direction:column; height:600px;">

              <div style="padding:1rem 1.25rem; border-bottom:1px solid #f0f0f0; display:flex; align-items:center; gap:0.75rem;">
                <div style="width:40px; height:40px; background:#e0e7ff; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:1.25rem;">🏠</div>
                <div>
                  <div style="font-weight:700; color:#1a1a2e;"><%= @selected.label %></div>
                  <div style="font-size:0.8rem; color:#888;"><%= @selected.sublabel %></div>
                </div>
                <div style="margin-left:auto; font-size:0.75rem; background:#dcfce7; color:#16a34a; padding:0.2rem 0.6rem; border-radius:999px; font-weight:600;">
                  🔒 Privado
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
                    <%
                      # is_mine se basa en sender, no en client
                      # así tanto el cliente como el owner ven sus
                      # propios mensajes a la derecha correctamente
                      is_mine = msg.sender == @username
                    %>
                    <div style={"display:flex; justify-content:#{if is_mine, do: "flex-end", else: "flex-start"};"}>
                      <div style={"max-width:70%; padding:0.75rem 1rem;
                        border-radius:#{if is_mine, do: "12px 12px 0 12px", else: "12px 12px 12px 0"};
                        background:#{if is_mine, do: "#4f46e5", else: "#f3f4f6"};
                        color:#{if is_mine, do: "white", else: "#1a1a2e"};"}>
                        <%= if !is_mine do %>
                          <div style="font-size:0.75rem; font-weight:600; margin-bottom:0.25rem; color:#4f46e5;">
                            <%= msg.sender %>
                          </div>
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
              <p>Selecciona una conversación para ver los mensajes</p>
            </div>
          <% end %>
        </div>

      </div>
    </div>
    """
  end

  # =====================================================================
  # HELPERS
  # =====================================================================

  defp conv_key(property_id, client, owner) do
    "#{property_id}__#{client}__#{owner}"
  end

  defp load_conv_messages(%{property_id: prop_id, client: client, owner: owner}) do
    MessageManager.get_conversation_messages(prop_id, client, owner)
  end

  defp label_for(props_map, property_id) do
    case Map.get(props_map, property_id) do
      nil -> "Propiedad #{property_id}"
      p -> "#{p.type} - #{p.city}"
    end
  end
end
