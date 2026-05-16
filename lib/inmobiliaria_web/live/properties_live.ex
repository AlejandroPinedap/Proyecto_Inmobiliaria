defmodule InmobiliariaWeb.PropertiesLive do
  use InmobiliariaWeb, :live_view

  alias Inmobiliaria.Property.PropertyManager
  alias Inmobiliaria.Users.UserManager
  alias Inmobiliaria.Operations.OperationLogger

  def mount(params, _session, socket) do
    username = Map.get(params, "user", "invitado")
    role = Map.get(params, "role", "cliente")
    properties = load_for_role(username, role)

    {:ok,
     assign(socket,
       username: username,
       role: role,
       properties: properties,
       filtered: properties,
       filter_city: "",
       filter_type: "",
       filter_modality: "",
       filter_status: "",
       show_form: false,
       edit_property: nil,
       form_error: nil,
       form: empty_form(username)
     )}
  end

  def handle_event("filter", params, socket) do
    city = Map.get(params, "city", "")
    type = Map.get(params, "type", "")
    modality = Map.get(params, "modality", "")
    status = Map.get(params, "status", "")

    filtered =
      socket.assigns.properties
      |> filter_by(:city, city)
      |> filter_by(:type, type)
      |> filter_by(:modality, modality)
      |> filter_by_status(status)

    {:noreply,
     assign(socket,
       filtered: filtered,
       filter_city: city,
       filter_type: type,
       filter_modality: modality,
       filter_status: status
     )}
  end

  def handle_event("clear_filters", _, socket) do
    {:noreply,
     assign(socket,
       filtered: socket.assigns.properties,
       filter_city: "",
       filter_type: "",
       filter_modality: "",
       filter_status: ""
     )}
  end

  def handle_event("show_form", _, socket) do
    {:noreply, assign(socket, show_form: true, edit_property: nil, form_error: nil)}
  end

  def handle_event("hide_form", _, socket) do
    {:noreply, assign(socket, show_form: false, edit_property: nil, form_error: nil)}
  end

  def handle_event("edit_property", %{"id" => id}, socket) do
    property = Enum.find(socket.assigns.properties, &(&1.id == id))
    {:noreply, assign(socket, edit_property: property, show_form: false, form_error: nil)}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, edit_property: nil, form_error: nil)}
  end

  def handle_event("update_property", params, socket) do
    username = socket.assigns.username
    role = socket.assigns.role
    property = socket.assigns.edit_property

    updated = %{
      property
      | type: params["type"],
        city: params["city"],
        price: String.to_integer(params["price"] || "0"),
        rooms: String.to_integer(params["rooms"] || "0"),
        area: String.to_integer(params["area"] || "0")
    }

    PropertyManager.update_property(updated)
    properties = load_for_role(username, role)

    {:noreply,
     assign(socket,
       properties: properties,
       filtered: properties,
       edit_property: nil,
       form_error: nil
     )}
  end

  def handle_event("create_property", params, socket) do
    username = socket.assigns.username
    role = socket.assigns.role

    modality =
      case role do
        "vendedor" -> "venta"
        "arrendador" -> "arriendo"
        _ -> params["modality"]
      end

    property = %{
      id: params["prop_id"],
      type: params["type"],
      modality: modality,
      city: params["city"],
      price: String.to_integer(params["price"] || "0"),
      rooms: String.to_integer(params["rooms"] || "0"),
      area: String.to_integer(params["area"] || "0"),
      owner: username,
      status: :available,
      buyer: ""
    }

    case PropertyManager.create_property(property) do
      {:ok, _} ->
        properties = load_for_role(username, role)

        {:noreply,
         assign(socket,
           properties: properties,
           filtered: properties,
           show_form: false,
           form_error: nil,
           form: empty_form(username)
         )}

      {:error, msg} ->
        {:noreply, assign(socket, form_error: msg)}
    end
  end

  def handle_event("change_status", %{"id" => id, "status" => status}, socket) do
    properties = socket.assigns.properties

    case Enum.find(properties, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      property ->
        updated = %{property | status: String.to_atom(status)}
        PropertyManager.update_property(updated)
        properties = load_for_role(socket.assigns.username, socket.assigns.role)
        {:noreply, assign(socket, properties: properties, filtered: properties)}
    end
  end

  # =========================
  # COMPRA — guarda buyer
  # =========================

  def handle_event("buy", %{"id" => id}, socket) do
    username = socket.assigns.username
    properties = socket.assigns.properties

    case Enum.find(properties, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      property when property.owner == username ->
        {:noreply, assign(socket, form_error: "No puedes comprar tu propia propiedad")}

      property ->
        # Guardamos el buyer junto con el nuevo estado
        updated = %{property | status: :sold, buyer: username}
        PropertyManager.update_property(updated)

        UserManager.add_points(username, 10)
        UserManager.add_points(property.owner, 15)

        OperationLogger.log_operation(
          username,
          property.owner,
          id,
          "compra",
          property.city,
          property.price
        )

        properties = load_for_role(username, socket.assigns.role)

        {:noreply,
         socket
         |> assign(properties: properties, filtered: properties, form_error: nil)
         |> push_navigate(to: "/properties?user=#{username}&role=#{socket.assigns.role}")}
    end
  end

  # =========================
  # ARRIENDO — guarda buyer
  # =========================

  def handle_event("rent", %{"id" => id}, socket) do
    username = socket.assigns.username
    properties = socket.assigns.properties

    case Enum.find(properties, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      property when property.owner == username ->
        {:noreply, assign(socket, form_error: "No puedes arrendar tu propia propiedad")}

      property ->
        # Guardamos el buyer junto con el nuevo estado
        updated = %{property | status: :rented, buyer: username}
        PropertyManager.update_property(updated)

        UserManager.add_points(username, 5)
        UserManager.add_points(property.owner, 10)

        OperationLogger.log_operation(
          username,
          property.owner,
          id,
          "arriendo",
          property.city,
          property.price
        )

        properties = load_for_role(username, socket.assigns.role)

        {:noreply,
         socket
         |> assign(properties: properties, filtered: properties, form_error: nil)
         |> push_navigate(to: "/properties?user=#{username}&role=#{socket.assigns.role}")}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="min-height:100vh; background:#f0f2f5; font-family:sans-serif;">

      <nav style="background:#1a1a2e; padding:1rem 2rem; display:flex; justify-content:space-between; align-items:center;">
        <span style="color:white; font-size:1.25rem; font-weight:700;">🏠 Inmobiliaria</span>
        <div style="display:flex; gap:1rem; align-items:center;">
          <a href={"/dashboard?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Dashboard</a>
          <a href={"/chat?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Chat</a>
          <a href="/" style="color:#f87171; text-decoration:none; font-weight:500;">Salir</a>
        </div>
      </nav>

      <div style="padding:2rem; max-width:1200px; margin:0 auto;">

        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1.5rem;">
          <div>
            <h1 style="color:#1a1a2e; margin:0 0 0.25rem;">🏘️ Propiedades</h1>
            <p style="color:#888; margin:0;">
              <%= length(@filtered) %> resultado(s) ·
              <span style={"color:#{role_color(@role)}; font-weight:600;"}><%= @role %></span>
            </p>
          </div>
          <%= if @role in ["vendedor", "arrendador"] do %>
            <button phx-click="show_form"
              style="padding:0.75rem 1.5rem; background:#4f46e5; color:white; border:none; border-radius:8px; font-weight:600; cursor:pointer;">
              ➕ Publicar Propiedad
            </button>
          <% end %>
        </div>

        <!-- FILTROS -->
        <form phx-change="filter" style="background:white; padding:1rem 1.25rem; border-radius:12px; margin-bottom:1.5rem; box-shadow:0 2px 8px rgba(0,0,0,0.06); display:flex; gap:0.75rem; flex-wrap:wrap; align-items:flex-end;">
          <div>
            <label style="display:block; font-size:0.75rem; color:#666; margin-bottom:0.25rem;">Ciudad</label>
            <input type="text" name="city" value={@filter_city} placeholder="Ej: Bogotá"
              style="padding:0.5rem 0.75rem; border:1px solid #ddd; border-radius:6px; font-size:0.875rem;"/>
          </div>
          <div>
            <label style="display:block; font-size:0.75rem; color:#666; margin-bottom:0.25rem;">Tipo</label>
            <select name="type" style="padding:0.5rem 0.75rem; border:1px solid #ddd; border-radius:6px; font-size:0.875rem;">
              <option value="">Todos</option>
              <option value="Casa" selected={@filter_type == "Casa"}>Casa</option>
              <option value="Apartamento" selected={@filter_type == "Apartamento"}>Apartamento</option>
              <option value="Local" selected={@filter_type == "Local"}>Local</option>
              <option value="Bodega" selected={@filter_type == "Bodega"}>Bodega</option>
              <option value="Lote" selected={@filter_type == "Lote"}>Lote</option>
              <option value="Finca" selected={@filter_type == "Finca"}>Finca</option>
            </select>
          </div>
          <div>
            <label style="display:block; font-size:0.75rem; color:#666; margin-bottom:0.25rem;">Modalidad</label>
            <select name="modality" style="padding:0.5rem 0.75rem; border:1px solid #ddd; border-radius:6px; font-size:0.875rem;">
              <option value="">Todas</option>
              <option value="venta" selected={@filter_modality == "venta"}>Venta</option>
              <option value="arriendo" selected={@filter_modality == "arriendo"}>Arriendo</option>
            </select>
          </div>
          <%= if @role in ["vendedor", "arrendador"] do %>
            <div>
              <label style="display:block; font-size:0.75rem; color:#666; margin-bottom:0.25rem;">Estado</label>
              <select name="status" style="padding:0.5rem 0.75rem; border:1px solid #ddd; border-radius:6px; font-size:0.875rem;">
                <option value="">Todos</option>
                <option value="available" selected={@filter_status == "available"}>Disponible</option>
                <option value="sold" selected={@filter_status == "sold"}>Vendida</option>
                <option value="rented" selected={@filter_status == "rented"}>Arrendada</option>
              </select>
            </div>
          <% end %>
          <button type="button" phx-click="clear_filters"
            style="padding:0.5rem 0.75rem; background:#f3f4f6; color:#666; border:1px solid #ddd; border-radius:6px; font-size:0.875rem; cursor:pointer;">
            Limpiar
          </button>
        </form>

        <!-- FORMULARIO CREAR -->
        <%= if @show_form do %>
          <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); margin-bottom:1.5rem; border-left:4px solid #4f46e5;">
            <h3 style="margin:0 0 1rem; color:#1a1a2e;">➕ Nueva Propiedad</h3>
            <%= if @form_error do %>
              <div style="background:#fee2e2; color:#dc2626; padding:0.75rem; border-radius:8px; margin-bottom:1rem;">⚠️ <%= @form_error %></div>
            <% end %>
            <form phx-submit="create_property">
              <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem; margin-bottom:1rem;">
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">ID Propiedad</label>
                  <input type="text" name="prop_id" required
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Tipo</label>
                  <select name="type" style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;">
                    <option value="Casa">Casa</option>
                    <option value="Apartamento">Apartamento</option>
                    <option value="Local">Local</option>
                    <option value="Lote">Lote</option>
                    <option value="Finca">Finca</option>
                  </select>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Ciudad</label>
                  <input type="text" name="city" required
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Precio</label>
                  <input type="number" name="price" required min="0"
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Habitaciones</label>
                  <input type="number" name="rooms" min="0" value="0"
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Área (m²)</label>
                  <input type="number" name="area" min="0" value="0"
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
              </div>
              <div style="display:flex; gap:0.75rem;">
                <button type="submit"
                  style="padding:0.6rem 1.5rem; background:#4f46e5; color:white; border:none; border-radius:8px; font-weight:600; cursor:pointer;">
                  Publicar
                </button>
                <button type="button" phx-click="hide_form"
                  style="padding:0.6rem 1.5rem; background:#f3f4f6; color:#666; border:1px solid #ddd; border-radius:8px; cursor:pointer;">
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <!-- FORMULARIO EDITAR -->
        <%= if @edit_property do %>
          <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); margin-bottom:1.5rem; border-left:4px solid #f59e0b;">
            <h3 style="margin:0 0 1rem; color:#1a1a2e;">✏️ Editar Propiedad · <%= @edit_property.id %></h3>
            <form phx-submit="update_property">
              <div style="display:grid; grid-template-columns:1fr 1fr; gap:0.75rem; margin-bottom:1rem;">
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Tipo</label>
                  <select name="type" style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;">
                    <option value="Casa" selected={@edit_property.type == "Casa"}>Casa</option>
                    <option value="Apartamento" selected={@edit_property.type == "Apartamento"}>Apartamento</option>
                    <option value="Local" selected={@edit_property.type == "Local"}>Local</option>
                    <option value="Lote" selected={@edit_property.type == "Lote"}>Lote</option>
                    <option value="Finca" selected={@edit_property.type == "Finca"}>Finca</option>
                  </select>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Ciudad</label>
                  <input type="text" name="city" required value={@edit_property.city}
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Precio</label>
                  <input type="number" name="price" required min="0" value={@edit_property.price}
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Habitaciones</label>
                  <input type="number" name="rooms" min="0" value={Map.get(@edit_property, :rooms, 0)}
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
                <div>
                  <label style="display:block; font-size:0.8rem; color:#666; margin-bottom:0.25rem;">Área (m²)</label>
                  <input type="number" name="area" min="0" value={Map.get(@edit_property, :area, 0)}
                    style="width:100%; padding:0.6rem; border:1px solid #ddd; border-radius:6px; box-sizing:border-box;"/>
                </div>
              </div>
              <div style="display:flex; gap:0.75rem;">
                <button type="submit"
                  style="padding:0.6rem 1.5rem; background:#f59e0b; color:white; border:none; border-radius:8px; font-weight:600; cursor:pointer;">
                  Guardar Cambios
                </button>
                <button type="button" phx-click="cancel_edit"
                  style="padding:0.6rem 1.5rem; background:#f3f4f6; color:#666; border:1px solid #ddd; border-radius:8px; cursor:pointer;">
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <!-- ERROR GLOBAL -->
        <%= if @form_error && !@show_form && !@edit_property do %>
          <div style="background:#fee2e2; color:#dc2626; padding:0.75rem; border-radius:8px; margin-bottom:1rem;">
            ⚠️ <%= @form_error %>
          </div>
        <% end %>

        <!-- LISTA DE PROPIEDADES -->
        <%= if Enum.empty?(@filtered) do %>
          <div style="background:white; padding:3rem; border-radius:12px; text-align:center; color:#999;">
            No se encontraron propiedades
          </div>
        <% else %>
          <div style="display:grid; grid-template-columns:repeat(auto-fill, minmax(300px, 1fr)); gap:1rem;">
            <%= for p <- @filtered do %>
              <div style="background:white; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); overflow:hidden;">

                <div style={"background:#{status_color(p.status)}15; padding:1rem 1.25rem; border-left:4px solid #{status_color(p.status)};"}>
                  <div style="display:flex; justify-content:space-between; align-items:center;">
                    <span style="font-weight:700; color:#1a1a2e;"><%= p.type %></span>
                    <span style={"font-size:0.75rem; padding:0.2rem 0.6rem; border-radius:999px; background:#{status_color(p.status)}25; color:#{status_color(p.status)}; font-weight:600;"}>
                      <%= status_label(p.status) %>
                    </span>
                  </div>
                  <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">📍 <%= p.city %></div>
                </div>

                <div style="padding:1rem 1.25rem;">
                  <div style="font-size:1.25rem; font-weight:700; color:#4f46e5; margin-bottom:0.5rem;">
                    $<%= format_number(p.price) %>
                  </div>
                  <div style="display:flex; gap:1rem; font-size:0.8rem; color:#888; margin-bottom:0.75rem; flex-wrap:wrap;">
                    <span>🏷️ <%= p.modality %></span>
                    <span>👤 <%= p.owner %></span>
                    <span>🔑 <%= p.id %></span>
                    <span>🛏️ <%= Map.get(p, :rooms, 0) %> hab</span>
                    <span>📐 <%= Map.get(p, :area, 0) %> m²</span>
                  </div>

                  <!-- BOTONES VENDEDOR/ARRENDADOR -->
                  <%= if @role in ["vendedor", "arrendador"] do %>
                    <div style="display:flex; gap:0.5rem; flex-wrap:wrap; margin-bottom:0.5rem;">
                      <%= if p.status != :available do %>
                        <button phx-click="change_status" phx-value-id={p.id} phx-value-status="available"
                          style="padding:0.3rem 0.75rem; background:#dcfce7; color:#16a34a; border:none; border-radius:6px; font-size:0.8rem; cursor:pointer;">
                          Disponible
                        </button>
                      <% end %>
                      <%= if @role == "vendedor" do %>
                        <%= if p.status != :sold do %>
                          <button phx-click="change_status" phx-value-id={p.id} phx-value-status="sold"
                            style="padding:0.3rem 0.75rem; background:#fee2e2; color:#dc2626; border:none; border-radius:6px; font-size:0.8rem; cursor:pointer;">
                            Vendida
                          </button>
                        <% end %>
                      <% end %>
                      <%= if @role == "arrendador" do %>
                        <%= if p.status != :rented do %>
                          <button phx-click="change_status" phx-value-id={p.id} phx-value-status="rented"
                            style="padding:0.3rem 0.75rem; background:#fef3c7; color:#92400e; border:none; border-radius:6px; font-size:0.8rem; cursor:pointer;">
                            Arrendada
                          </button>
                        <% end %>
                      <% end %>
                      <button phx-click="edit_property" phx-value-id={p.id}
                        style="padding:0.3rem 0.75rem; background:#e0e7ff; color:#4f46e5; border:none; border-radius:6px; font-size:0.8rem; cursor:pointer;">
                        ✏️ Editar
                      </button>
                    </div>
                  <% end %>

                  <!-- BOTONES COMPRA/ARRIENDO/CONTACTAR -->
                  <%= if p.status == :available && p.owner != @username do %>
                    <div style="display:flex; gap:0.5rem; margin-top:0.5rem;">
                      <%= if p.modality == "venta" do %>
                        <button phx-click="buy" phx-value-id={p.id}
                          style="flex:1; padding:0.5rem; background:#4f46e5; color:white; border:none; border-radius:8px; font-weight:600; cursor:pointer; font-size:0.875rem;">
                          🛒 Comprar
                        </button>
                      <% end %>
                      <%= if p.modality == "arriendo" do %>
                        <button phx-click="rent" phx-value-id={p.id}
                          style="flex:1; padding:0.5rem; background:#f59e0b; color:white; border:none; border-radius:8px; font-weight:600; cursor:pointer; font-size:0.875rem;">
                          🔑 Arrendar
                        </button>
                      <% end %>
                      <a href={"/chat?user=#{@username}&role=#{@role}&property=#{p.id}&owner=#{p.owner}"}
                        style="flex:1; padding:0.5rem; background:#dcfce7; color:#16a34a; border-radius:8px; font-weight:600; font-size:0.875rem; text-align:center; text-decoration:none;">
                        💬 Contactar
                      </a>
                    </div>
                  <% end %>

                </div>
              </div>
            <% end %>
          </div>
        <% end %>

      </div>
    </div>
    """
  end

  defp load_for_role(username, role) do
    case role do
      "vendedor" -> PropertyManager.search_by_owner(username)
      "arrendador" -> PropertyManager.search_by_owner(username)
      _ -> PropertyManager.available_properties()
    end
  end

  defp filter_by(list, _field, ""), do: list

  defp filter_by(list, field, value) do
    Enum.filter(list, fn p ->
      String.contains?(
        String.downcase(to_string(Map.get(p, field, ""))),
        String.downcase(value)
      )
    end)
  end

  defp filter_by_status(list, ""), do: list

  defp filter_by_status(list, status) do
    Enum.filter(list, &(&1.status == String.to_atom(status)))
  end

  defp empty_form(username) do
    %{id: "", type: "Casa", modality: "venta", city: "", price: "", owner: username}
  end

  defp status_color(:available), do: "#16a34a"
  defp status_color(:sold), do: "#dc2626"
  defp status_color(:rented), do: "#f59e0b"
  defp status_color(_), do: "#888"

  defp status_label(:available), do: "Disponible"
  defp status_label(:sold), do: "Vendida"
  defp status_label(:rented), do: "Arrendada"
  defp status_label(other), do: to_string(other)

  defp format_number(price) when is_integer(price) do
    price
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(".")
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.join("")
  end

  defp format_number(price), do: to_string(price)

  defp role_color("vendedor"), do: "#f59e0b"
  defp role_color("arrendador"), do: "#0891b2"
  defp role_color(_), do: "#16a34a"
end
