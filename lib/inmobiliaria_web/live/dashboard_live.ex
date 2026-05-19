defmodule InmobiliariaWeb.DashboardLive do
  use InmobiliariaWeb, :live_view

  alias Inmobiliaria.Property.PropertyManager
  alias Inmobiliaria.Users.UserManager

  # =====================================================================
  # MOUNT
  # =====================================================================

  def mount(params, _session, socket) do
    username = Map.get(params, "user", "invitado")
    role = Map.get(params, "role", "cliente")

    properties = PropertyManager.list_properties()
    _all_users = UserManager.load_users()
    full_ranking = UserManager.ranking_all()

    # Propiedades visibles según rol
    visible_properties =
      case role do
        r when r in ["vendedor", "arrendador"] ->
          Enum.filter(properties, &(&1.owner == username))

        _ ->
          Enum.filter(properties, &(&1.status == :available))
      end

    # Estadísticas según rol
    stats =
      case role do
        r when r in ["vendedor", "arrendador"] ->
          %{
            total: length(visible_properties),
            available: Enum.count(visible_properties, &(&1.status == :available)),
            sold: Enum.count(visible_properties, &(&1.status == :sold)),
            rented: Enum.count(visible_properties, &(&1.status == :rented)),
            total_users: nil
          }

        _ ->
          compradas = PropertyManager.search_by_buyer(username)

          %{
            total: length(visible_properties),
            available: length(visible_properties),
            sold: length(compradas),
            rented: nil,
            total_users: nil
          }
      end

    # Ranking: top 5 + posición del usuario actual
    top_ranking = Enum.take(full_ranking, 5)
    user_position = Enum.find_index(full_ranking, &(&1.username == username))
    user_rank = if user_position != nil, do: user_position + 1, else: nil
    user_in_top5? = user_rank != nil and user_rank <= 5

    current_user_data = Enum.find(full_ranking, &(&1.username == username))

    # Historial
    # Para vendedores/arrendadores: sus propiedades publicadas (todas)
    # Para clientes: solo las propiedades que ellos compraron/arrendaron
    #   (filtradas por el campo buyer guardado en properties.dat)
    history =
      case role do
        r when r in ["vendedor", "arrendador"] ->
          properties
          |> Enum.filter(&(&1.owner == username))
          |> Enum.sort_by(&status_sort_order(&1.status))

        _ ->
          PropertyManager.search_by_buyer(username)
      end

    # Gráficos
    by_city =
      visible_properties
      |> Enum.group_by(& &1.city)
      |> Enum.map(fn {city, props} -> {city, length(props)} end)
      |> Enum.sort_by(fn {_, count} -> -count end)
      |> Enum.take(5)

    by_type =
      visible_properties
      |> Enum.group_by(& &1.type)
      |> Enum.map(fn {type, props} -> {type, length(props)} end)

    unread_count = Inmobiliaria.NotificationManager.get_count(username)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Inmobiliaria.PubSub, "notifications:#{username}")
    end

    {:ok,
     assign(socket,
       username: username,
       role: role,
       stats: stats,
       by_city: by_city,
       by_type: by_type,
       top_ranking: top_ranking,
       full_ranking: full_ranking,
       user_rank: user_rank,
       user_in_top5?: user_in_top5?,
       current_user_data: current_user_data,
       history: history,
       properties: Enum.take(visible_properties, 5),
       # Tab activo: "dashboard" | "ranking" | "historial"
       active_tab: "dashboard",
       unread_count: unread_count
     )}
  end

  # =====================================================================
  # EVENTOS
  # =====================================================================

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_info({:new_notification, count}, socket) do
    {:noreply, assign(socket, unread_count: count)}
  end

  # =====================================================================
  # RENDER PRINCIPAL
  # =====================================================================

  def render(assigns) do
  ~H"""
  <div style="display:flex; min-height:100vh; font-family:'Segoe UI',sans-serif;">

    <!-- ========== SIDEBAR ========== -->
    <aside style="width:240px; min-width:240px; background:#1a1a2e; display:flex; flex-direction:column; padding:0; box-shadow:4px 0 12px rgba(0,0,0,0.3);">

      <!-- Logo -->
      <div style="padding:1.5rem 1.25rem; border-bottom:1px solid rgba(255,255,255,0.08);">
        <div style="font-size:1.2rem; font-weight:800; color:white;">🏠 Inmobiliaria</div>
        <div style="font-size:0.7rem; color:#a5b4fc; margin-top:0.2rem; letter-spacing:0.05em; text-transform:uppercase;">Sistema Virtual</div>
      </div>

      <!-- Usuario -->
      <div style="padding:1.25rem; border-bottom:1px solid rgba(255,255,255,0.08); display:flex; align-items:center; gap:0.75rem;">
        <div style={"width:38px; height:38px; border-radius:50%; background:#{role_color(@role)}; display:flex; align-items:center; justify-content:center; font-weight:700; color:white; font-size:1rem; flex-shrink:0;"}>
          <%= String.upcase(String.first(@username)) %>
        </div>
        <div>
          <div style="color:white; font-weight:600; font-size:0.875rem;"><%= @username %></div>
          <div style={"color:#{role_color(@role)}; font-size:0.7rem; text-transform:capitalize; font-weight:500;"}><%= @role %></div>
        </div>
      </div>

      <!-- Menú de navegación -->
      <nav style="flex:1; padding:1rem 0;">

        <div style="padding:0.25rem 1.25rem; font-size:0.65rem; color:#6b7280; text-transform:uppercase; letter-spacing:0.08em; margin-bottom:0.25rem;">
          Menú
        </div>

        <button phx-click="switch_tab" phx-value-tab="dashboard"
          style={"width:100%; text-align:left; padding:0.7rem 1.25rem; border:none; cursor:pointer; display:flex; align-items:center; gap:0.75rem; font-size:0.875rem; font-weight:500; transition:all 0.15s;
            #{if @active_tab == "dashboard", do: "background:rgba(79,70,229,0.35); color:white; border-left:3px solid #4f46e5;", else: "background:transparent; color:#9ca3af; border-left:3px solid transparent;"}"}
        >
          📊 <span>Resumen</span>
        </button>

        <button phx-click="switch_tab" phx-value-tab="ranking"
          style={"width:100%; text-align:left; padding:0.7rem 1.25rem; border:none; cursor:pointer; display:flex; align-items:center; gap:0.75rem; font-size:0.875rem; font-weight:500; transition:all 0.15s;
            #{if @active_tab == "ranking", do: "background:rgba(124,58,237,0.35); color:white; border-left:3px solid #7c3aed;", else: "background:transparent; color:#9ca3af; border-left:3px solid transparent;"}"}
        >
          🏆 <span>Ranking</span>
        </button>

        <button phx-click="switch_tab" phx-value-tab="historial"
          style={"width:100%; text-align:left; padding:0.7rem 1.25rem; border:none; cursor:pointer; display:flex; align-items:center; gap:0.75rem; font-size:0.875rem; font-weight:500; transition:all 0.15s;
            #{if @active_tab == "historial", do: "background:rgba(8,145,178,0.35); color:white; border-left:3px solid #0891b2;", else: "background:transparent; color:#9ca3af; border-left:3px solid transparent;"}"}
        >
          📋 <span>Historial</span>
        </button>

        <div style="padding:0.25rem 1.25rem; font-size:0.65rem; color:#6b7280; text-transform:uppercase; letter-spacing:0.08em; margin:1rem 0 0.25rem;">
          Accesos
        </div>

        <a href={"/properties?user=#{@username}&role=#{@role}"}
          style="display:flex; align-items:center; gap:0.75rem; padding:0.7rem 1.25rem; color:#9ca3af; text-decoration:none; font-size:0.875rem; font-weight:500; border-left:3px solid transparent; transition:all 0.15s;"
          onmouseover="this.style.color='white'" onmouseout="this.style.color='#9ca3af'">
          🏘️ <span>Propiedades</span>
        </a>

        <a href={"/chat?user=#{@username}&role=#{@role}"}
          style="display:flex; align-items:center; gap:0.75rem; padding:0.7rem 1.25rem; color:#9ca3af; text-decoration:none; font-size:0.875rem; font-weight:500; border-left:3px solid transparent; transition:all 0.15s;"
          onmouseover="this.style.color='white'" onmouseout="this.style.color='#9ca3af'">
          💬
          <span>Chat</span>
          <%= if @unread_count > 0 do %>
            <span style="margin-left:auto; background:#dc2626; color:white; font-size:0.65rem; padding:0.1rem 0.45rem; border-radius:999px; font-weight:700;">
              <%= @unread_count %>
            </span>
          <% end %>
        </a>

      </nav>

      <!-- Botón salir -->
      <div style="padding:1rem 1.25rem; border-top:1px solid rgba(255,255,255,0.08);">
        <a href="/"
          style="display:flex; align-items:center; gap:0.75rem; color:#f87171; text-decoration:none; font-size:0.875rem; font-weight:500; padding:0.5rem 0;">
          🚪 <span>Cerrar sesión</span>
        </a>
      </div>
    </aside>

    <!-- ========== CONTENIDO PRINCIPAL ========== -->
    <div style="flex:1; display:flex; flex-direction:column; overflow:hidden;">

      <!-- Topbar -->
      <header style="background:white; padding:1rem 2rem; display:flex; justify-content:space-between; align-items:center; box-shadow:0 1px 4px rgba(0,0,0,0.08); border-bottom:1px solid #e5e7eb;">
        <div>
          <h1 style="margin:0; font-size:1.1rem; font-weight:700; color:#1a1a2e;">
            <%= case @active_tab do %>
              <% "dashboard" -> %> 📊 Resumen General
              <% "ranking" -> %> 🏆 Ranking Global
              <% "historial" -> %> 📋 Historial
            <% end %>
          </h1>
          <p style="margin:0; font-size:0.75rem; color:#9ca3af;">
            Bienvenido, <strong><%= @username %></strong>
            <%= if @user_rank do %>
              · 🏅 Posición <strong>#<%= @user_rank %></strong>
            <% end %>
          </p>
        </div>
        <div style="display:flex; align-items:center; gap:0.5rem;">
          <span style={"background:#{role_color(@role)}18; color:#{role_color(@role)}; font-size:0.75rem; font-weight:600; padding:0.3rem 0.75rem; border-radius:999px; text-transform:capitalize;"}>
            <%= @role %>
          </span>
        </div>
      </header>

      <!-- Área de contenido -->
      <main style="flex:1; overflow-y:auto; padding:1.5rem 2rem; background:#f0f2f5;">
        <%= if @active_tab == "dashboard" do %>
          <%= render_dashboard(assigns) %>
        <% end %>
        <%= if @active_tab == "ranking" do %>
          <%= render_ranking(assigns) %>
        <% end %>
        <%= if @active_tab == "historial" do %>
          <%= render_historial(assigns) %>
        <% end %>
      </main>

    </div>
  </div>
  """
end

  # =====================================================================
  # RENDER: DASHBOARD (resumen original)
  # =====================================================================

  defp render_dashboard(assigns) do
    ~H"""
    <!-- Tarjetas de estadísticas -->
    <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(180px, 1fr)); gap:1rem; margin-bottom:2rem;">

      <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); border-left:4px solid #4f46e5;">
        <div style="font-size:2rem; font-weight:700; color:#4f46e5;"><%= @stats.total %></div>
        <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">
          <%= if @role in ["vendedor", "arrendador"], do: "Mis Propiedades", else: "Disponibles en el mercado" %>
        </div>
      </div>

      <%= if @role in ["vendedor", "arrendador"] do %>
        <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); border-left:4px solid #16a34a;">
          <div style="font-size:2rem; font-weight:700; color:#16a34a;"><%= @stats.available %></div>
          <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">Disponibles</div>
        </div>
        <%= if @stats.sold != nil do %>
          <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); border-left:4px solid #dc2626;">
            <div style="font-size:2rem; font-weight:700; color:#dc2626;"><%= @stats.sold %></div>
            <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">Vendidas</div>
          </div>
        <% end %>
        <%= if @stats.rented != nil do %>
          <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); border-left:4px solid #f59e0b;">
            <div style="font-size:2rem; font-weight:700; color:#f59e0b;"><%= @stats.rented %></div>
            <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">Arrendadas</div>
          </div>
        <% end %>
        <%= if @stats.total_users != nil do %>
          <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); border-left:4px solid #0891b2;">
            <div style="font-size:2rem; font-weight:700; color:#0891b2;"><%= @stats.total_users %></div>
            <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">Usuarios</div>
          </div>
        <% end %>
      <% else %>
        <%= if @stats.sold != nil and @stats.sold > 0 do %>
          <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); border-left:4px solid #7c3aed;">
            <div style="font-size:2rem; font-weight:700; color:#7c3aed;"><%= @stats.sold %></div>
            <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">Mis compras y arriendos</div>
          </div>
        <% end %>
      <% end %>

    </div>

    <!-- Gráficos + Propiedades -->
    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem; margin-bottom:2rem;">
      <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <h3 style="margin:0 0 1rem; color:#1a1a2e;">📍 Por Ciudad</h3>
        <%= if Enum.empty?(@by_city) do %>
          <p style="color:#999;">Sin datos</p>
        <% else %>
          <%= for {city, count} <- @by_city do %>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.75rem;">
              <span style="color:#444;"><%= city %></span>
              <div style="display:flex; align-items:center; gap:0.5rem;">
                <div style={"background:#e0e7ff; border-radius:4px; height:8px; width:#{min(count * 20, 120)}px;"}></div>
                <span style="color:#4f46e5; font-weight:600; min-width:20px;"><%= count %></span>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
      <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <h3 style="margin:0 0 1rem; color:#1a1a2e;">🏗️ Por Tipo</h3>
        <%= if Enum.empty?(@by_type) do %>
          <p style="color:#999;">Sin datos</p>
        <% else %>
          <%= for {type, count} <- @by_type do %>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.75rem;">
              <span style="color:#444;"><%= type %></span>
              <div style="display:flex; align-items:center; gap:0.5rem;">
                <div style={"background:#dcfce7; border-radius:4px; height:8px; width:#{min(count * 20, 120)}px;"}></div>
                <span style="color:#16a34a; font-weight:600; min-width:20px;"><%= count %></span>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>

    <!-- Propiedades + Acciones rápidas -->
    <div style="display:grid; grid-template-columns:1fr 1fr; gap:1rem;">
      <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <h3 style="margin:0 0 1rem; color:#1a1a2e;">
          🏘️ <%= if @role in ["vendedor", "arrendador"], do: "Mis Propiedades", else: "Propiedades Disponibles" %>
        </h3>
        <%= if Enum.empty?(@properties) do %>
          <p style="color:#999;">Sin propiedades registradas</p>
        <% else %>
          <%= for p <- @properties do %>
            <div style="border-bottom:1px solid #f0f0f0; padding:0.75rem 0;">
              <div style="display:flex; justify-content:space-between;">
                <span style="font-weight:600; color:#1a1a2e;"><%= p.type %> - <%= p.city %></span>
                <span style={"font-size:0.75rem; padding:0.2rem 0.5rem; border-radius:999px; background:#{status_color(p.status)}20; color:#{status_color(p.status)};"}>
                  <%= status_label(p.status) %>
                </span>
              </div>
              <div style="color:#888; font-size:0.875rem; margin-top:0.25rem;">
                $<%= format_number(p.price) %> · <%= p.modality %>
              </div>
            </div>
          <% end %>
        <% end %>
        <a href={"/properties?user=#{@username}&role=#{@role}"} style="display:block; text-align:center; margin-top:1rem; color:#4f46e5; text-decoration:none; font-size:0.875rem;">
          Ver todas →
        </a>
      </div>

      <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08);">
        <h3 style="margin:0 0 1rem; color:#1a1a2e;">💡 Acciones Rápidas</h3>
        <div style="display:flex; flex-direction:column; gap:0.75rem;">
          <a href={"/properties?user=#{@username}&role=#{@role}"}
            style="padding:0.75rem 1rem; background:#e0e7ff; color:#4f46e5; border-radius:8px; text-decoration:none; font-weight:500;">
            🔍 Ver Propiedades
          </a>
          <a href={"/chat?user=#{@username}&role=#{@role}"}
            style="padding:0.75rem 1rem; background:#dcfce7; color:#16a34a; border-radius:8px; text-decoration:none; font-weight:500;">
            💬 Ir al Chat
          </a>
          <%= if @role in ["vendedor", "arrendador"] do %>
            <a href={"/properties?user=#{@username}&role=#{@role}"}
              style="padding:0.75rem 1rem; background:#fef3c7; color:#92400e; border-radius:8px; text-decoration:none; font-weight:500;">
              ➕ Publicar Propiedad
            </a>
          <% end %>
          <button phx-click="switch_tab" phx-value-tab="ranking"
            style="padding:0.75rem 1rem; background:#f3e8ff; color:#7c3aed; border-radius:8px; font-weight:500; border:none; cursor:pointer; text-align:left;">
            🏆 Ver Ranking Completo
          </button>
          <button phx-click="switch_tab" phx-value-tab="historial"
            style="padding:0.75rem 1rem; background:#e0f2fe; color:#0891b2; border-radius:8px; font-weight:500; border:none; cursor:pointer; text-align:left;">
            📋 Ver Historial
          </button>
        </div>
      </div>
    </div>
    """
  end

  # =====================================================================
  # RENDER: RANKING INTERACTIVO
  # =====================================================================

  defp render_ranking(assigns) do
    ~H"""
    <div style="display:grid; grid-template-columns:2fr 1fr; gap:1.5rem;">

      <!-- Tabla de ranking completo -->
      <div style="background:white; border-radius:16px; box-shadow:0 2px 12px rgba(0,0,0,0.08); overflow:hidden;">
        <div style="background:linear-gradient(135deg,#1a1a2e,#4f46e5); padding:1.5rem;">
          <h2 style="color:white; margin:0; font-size:1.25rem;">🏆 Ranking Global</h2>
          <p style="color:#a5b4fc; margin:0.25rem 0 0; font-size:0.875rem;">
            <%= length(@full_ranking) %> participantes
          </p>
        </div>

        <div style="padding:0;">
          <%= for {user, idx} <- Enum.with_index(@full_ranking, 1) do %>
            <% is_me = user.username == @username %>
            <div style={"display:flex; align-items:center; padding:0.9rem 1.5rem; border-bottom:1px solid #f0f0f0; transition:background 0.15s;
              #{if is_me, do: "background:linear-gradient(90deg,#f3e8ff,#ede9fe); border-left:4px solid #7c3aed;", else: "background:white; border-left:4px solid transparent;"}"}
            >
              <!-- Posición -->
              <div style={"min-width:40px; font-size:#{if idx <= 3, do: "1.4rem", else: "0.95rem"}; font-weight:700; color:#{rank_color(idx)};"}>
                <%= medal(idx) %>
              </div>

              <!-- Nombre + role -->
              <div style="flex:1; margin-left:0.75rem;">
                <div style={"font-weight:#{if is_me, do: "700", else: "500"}; color:#{if is_me, do: "#7c3aed", else: "#1a1a2e"}; font-size:0.95rem;"}>
                  <%= user.username %>
                  <%= if is_me do %>
                    <span style="font-size:0.7rem; background:#7c3aed; color:white; padding:0.1rem 0.4rem; border-radius:999px; margin-left:0.4rem; vertical-align:middle;">TÚ</span>
                  <% end %>
                </div>
                <div style={"font-size:0.75rem; color:#{role_color(user.role)}; font-weight:500; text-transform:capitalize;"}>
                  <%= user.role %>
                </div>
              </div>

              <!-- Barra de puntos -->
              <div style="margin-right:1rem; flex:1; max-width:100px;">
                <% max_pts = if length(@full_ranking) > 0, do: hd(@full_ranking).points, else: 1 %>
                <% max_pts = if max_pts == 0, do: 1, else: max_pts %>
                <% pct = round(user.points * 100 / max_pts) %>
                <div style="background:#f0f0f0; border-radius:999px; height:6px; overflow:hidden;">
                  <div style={"height:100%; border-radius:999px; width:#{pct}%;
                    background:#{if is_me, do: "#7c3aed", else: rank_bar_color(idx)};"}>
                  </div>
                </div>
              </div>

              <!-- Puntos -->
              <div style={"min-width:70px; text-align:right; font-weight:700; font-size:0.95rem; color:#{if is_me, do: "#7c3aed", else: "#f59e0b"};"}>
                <%= user.points %> pts
              </div>
            </div>
          <% end %>

          <%= if Enum.empty?(@full_ranking) do %>
            <div style="padding:2rem; text-align:center; color:#999;">Sin usuarios registrados aún</div>
          <% end %>
        </div>
      </div>

      <!-- Panel lateral: tu posición + stats -->
      <div style="display:flex; flex-direction:column; gap:1rem;">

        <!-- Tu tarjeta de posición -->
        <div style="background:linear-gradient(135deg,#7c3aed,#4f46e5); border-radius:16px; padding:1.5rem; color:white; box-shadow:0 4px 20px rgba(124,58,237,0.35);">
          <div style="font-size:0.8rem; opacity:0.8; text-transform:uppercase; letter-spacing:0.05em; margin-bottom:0.5rem;">Tu posición</div>
          <%= if @user_rank do %>
            <div style="font-size:3.5rem; font-weight:800; line-height:1;">
              #<%= @user_rank %>
            </div>
            <div style="font-size:0.9rem; opacity:0.85; margin-top:0.25rem;">
              de <%= length(@full_ranking) %> usuarios
            </div>
            <div style="margin-top:1rem; padding-top:1rem; border-top:1px solid rgba(255,255,255,0.2);">
              <div style="font-size:0.8rem; opacity:0.8;">Tus puntos</div>
              <div style="font-size:1.8rem; font-weight:700;">
                <%= if @current_user_data, do: @current_user_data.points, else: 0 %> pts
              </div>
            </div>
            <%= if @user_rank == 1 do %>
              <div style="margin-top:0.75rem; font-size:0.85rem; background:rgba(255,255,255,0.15); border-radius:8px; padding:0.5rem; text-align:center;">
                👑 ¡Estás en el primer lugar!
              </div>
            <% else %>
              <% prev = Enum.at(@full_ranking, @user_rank - 2) %>
              <%= if prev do %>
                <div style="margin-top:0.75rem; font-size:0.8rem; background:rgba(255,255,255,0.15); border-radius:8px; padding:0.5rem;">
                  📈 Te faltan <strong><%= prev.points - (if @current_user_data, do: @current_user_data.points, else: 0) %></strong> pts para superar a <strong><%= prev.username %></strong>
                </div>
              <% end %>
            <% end %>
          <% else %>
            <div style="font-size:1.1rem; opacity:0.8;">Sin posición aún</div>
          <% end %>
        </div>

        <!-- Top 3 resumen -->
        <div style="background:white; border-radius:16px; padding:1.5rem; box-shadow:0 2px 8px rgba(0,0,0,0.08);">
          <h4 style="margin:0 0 1rem; color:#1a1a2e; font-size:0.95rem;">🥇 Top 3</h4>
          <%= for {user, idx} <- Enum.with_index(Enum.take(@full_ranking, 3), 1) do %>
            <div style="display:flex; align-items:center; gap:0.75rem; margin-bottom:0.75rem;">
              <span style="font-size:1.5rem;"><%= medal(idx) %></span>
              <div style="flex:1;">
                <div style={"font-weight:600; font-size:0.9rem; color:#{if user.username == @username, do: "#7c3aed", else: "#1a1a2e"};"}>
                  <%= user.username %>
                  <%= if user.username == @username do %>
                    <span style="font-size:0.65rem; background:#7c3aed; color:white; padding:0.1rem 0.35rem; border-radius:999px; margin-left:0.3rem;">TÚ</span>
                  <% end %>
                </div>
                <div style="font-size:0.75rem; color:#888;"><%= user.role %></div>
              </div>
              <span style="font-weight:700; color:#f59e0b; font-size:0.9rem;"><%= user.points %> pts</span>
            </div>
          <% end %>
          <%= if Enum.empty?(@full_ranking) do %>
            <p style="color:#999; font-size:0.875rem;">Sin datos</p>
          <% end %>
        </div>

        <!-- Distribución por rol -->
        <div style="background:white; border-radius:16px; padding:1.5rem; box-shadow:0 2px 8px rgba(0,0,0,0.08);">
          <h4 style="margin:0 0 1rem; color:#1a1a2e; font-size:0.95rem;">👥 Usuarios por rol</h4>
          <% by_role = Enum.group_by(@full_ranking, & &1.role) %>
          <%= for {r, users_in_role} <- by_role do %>
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.5rem; font-size:0.875rem;">
              <span style={"color:#{role_color(r)}; font-weight:600; text-transform:capitalize;"}><%= r %></span>
              <span style="background:#f3f4f6; padding:0.2rem 0.6rem; border-radius:999px; font-weight:600; color:#374151;">
                <%= length(users_in_role) %>
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # =====================================================================
  # RENDER: HISTORIAL
  # =====================================================================

  defp render_historial(assigns) do
    ~H"""
    <div style="background:white; border-radius:16px; box-shadow:0 2px 12px rgba(0,0,0,0.08); overflow:hidden;">
      <!-- Header -->
      <div style={"background:linear-gradient(135deg,#{if @role in ["vendedor","arrendador"], do: "#0891b2,#0e7490", else: "#16a34a,#15803d"}); padding:1.5rem;"}>
        <h2 style="color:white; margin:0; font-size:1.25rem;">
          <%= if @role in ["vendedor", "arrendador"] do %>
            🏘️ Mis Propiedades Publicadas
          <% else %>
            📦 Mis Compras y Arriendos
          <% end %>
        </h2>
        <p style="color:rgba(255,255,255,0.8); margin:0.25rem 0 0; font-size:0.875rem;">
          <%= length(@history) %> registros encontrados
        </p>
      </div>

      <!-- Tabla -->
      <%= if Enum.empty?(@history) do %>
        <div style="padding:3rem; text-align:center;">
          <div style="font-size:3rem; margin-bottom:1rem;">📭</div>
          <p style="color:#999; font-size:1rem;">
            <%= if @role in ["vendedor", "arrendador"] do %>
              Aún no has publicado propiedades
            <% else %>
              Aún no has comprado ni arrendado ninguna propiedad
            <% end %>
          </p>
        </div>
      <% else %>
        <!-- Cabecera tabla -->
        <div style="display:grid; grid-template-columns:0.5fr 1fr 1fr 1fr 1fr 1fr; gap:0; background:#f8fafc; border-bottom:2px solid #e5e7eb; padding:0.75rem 1.5rem;">
          <span style="font-size:0.75rem; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:0.05em;">#ID</span>
          <span style="font-size:0.75rem; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:0.05em;">Tipo</span>
          <span style="font-size:0.75rem; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:0.05em;">Ciudad</span>
          <span style="font-size:0.75rem; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:0.05em;">Modalidad</span>
          <span style="font-size:0.75rem; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:0.05em;">Precio</span>
          <span style="font-size:0.75rem; font-weight:700; color:#6b7280; text-transform:uppercase; letter-spacing:0.05em;">Estado</span>
        </div>

        <%= for p <- @history do %>
          <div style="display:grid; grid-template-columns:0.5fr 1fr 1fr 1fr 1fr 1fr; gap:0; padding:1rem 1.5rem; border-bottom:1px solid #f0f0f0; align-items:center; transition:background 0.1s;"
               onmouseover="this.style.background='#fafafa'"
               onmouseout="this.style.background='white'">
            <span style="font-size:0.8rem; color:#94a3b8; font-family:monospace;"><%= String.slice(p.id, 0, 8) %></span>
            <span style="font-weight:600; color:#1a1a2e; font-size:0.9rem;">
              <%= property_icon(p.type) %> <%= p.type %>
            </span>
            <span style="color:#444; font-size:0.9rem;">📍 <%= p.city %></span>
            <span style={"font-size:0.8rem; padding:0.25rem 0.6rem; border-radius:999px; font-weight:600; width:fit-content;
              #{if p.modality == "venta", do: "background:#dbeafe; color:#1d4ed8;", else: "background:#fef3c7; color:#92400e;"}"}
            >
              <%= p.modality %>
            </span>
            <span style="font-weight:700; color:#1a1a2e; font-size:0.9rem;">$<%= format_number(p.price) %></span>
            <span style={"font-size:0.8rem; padding:0.25rem 0.6rem; border-radius:999px; font-weight:600; width:fit-content;
              background:#{status_color(p.status)}18; color:#{status_color(p.status)};"}>
              <%= status_label(p.status) %>
            </span>
          </div>
        <% end %>

        <!-- Resumen de historial -->
        <%= if @role in ["vendedor", "arrendador"] do %>
          <div style="display:flex; gap:1rem; padding:1.25rem 1.5rem; background:#f8fafc; border-top:2px solid #e5e7eb;">
            <div style="display:flex; align-items:center; gap:0.5rem; font-size:0.875rem;">
              <span style="width:10px; height:10px; border-radius:50%; background:#16a34a; display:inline-block;"></span>
              <span style="color:#666;">Disponibles: <strong><%= Enum.count(@history, &(&1.status == :available)) %></strong></span>
            </div>
            <div style="display:flex; align-items:center; gap:0.5rem; font-size:0.875rem;">
              <span style="width:10px; height:10px; border-radius:50%; background:#dc2626; display:inline-block;"></span>
              <span style="color:#666;">Vendidas: <strong><%= Enum.count(@history, &(&1.status == :sold)) %></strong></span>
            </div>
            <div style="display:flex; align-items:center; gap:0.5rem; font-size:0.875rem;">
              <span style="width:10px; height:10px; border-radius:50%; background:#f59e0b; display:inline-block;"></span>
              <span style="color:#666;">Arrendadas: <strong><%= Enum.count(@history, &(&1.status == :rented)) %></strong></span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>


    """
  end

  # =====================================================================
  # HELPERS
  # =====================================================================

  defp status_color(:available), do: "#16a34a"
  defp status_color(:sold), do: "#dc2626"
  defp status_color(:rented), do: "#f59e0b"
  defp status_color(_), do: "#888"

  defp status_label(:available), do: "Disponible"
  defp status_label(:sold), do: "Vendida"
  defp status_label(:rented), do: "Arrendada"
  defp status_label(other), do: to_string(other)

  defp status_sort_order(:sold), do: 0
  defp status_sort_order(:rented), do: 1
  defp status_sort_order(:available), do: 2
  defp status_sort_order(_), do: 3

  defp medal(1), do: "🥇"
  defp medal(2), do: "🥈"
  defp medal(3), do: "🥉"
  defp medal(n), do: "##{n}"

  defp rank_color(1), do: "#f59e0b"
  defp rank_color(2), do: "#9ca3af"
  defp rank_color(3), do: "#b45309"
  defp rank_color(_), do: "#6b7280"

  defp rank_bar_color(1), do: "#f59e0b"
  defp rank_bar_color(2), do: "#9ca3af"
  defp rank_bar_color(3), do: "#b45309"
  defp rank_bar_color(_), do: "#4f46e5"

  defp property_icon("Casa"), do: "🏠"
  defp property_icon("Apartamento"), do: "🏢"
  defp property_icon("Local"), do: "🏪"
  defp property_icon("Bodega"), do: "🏭"
  defp property_icon("Terreno"), do: "🌳"
  defp property_icon(_), do: "🏗️"

  defp format_number(price) when is_float(price) do
    price |> trunc() |> format_number()
  end

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
