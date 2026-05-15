defmodule InmobiliariaWeb.DashboardLive do
  use InmobiliariaWeb, :live_view

  alias Inmobiliaria.Property.PropertyManager
  alias Inmobiliaria.Users.UserManager

  def mount(params, _session, socket) do
    username = Map.get(params, "user", "invitado")
    role = Map.get(params, "role", "cliente")

    properties = PropertyManager.list_properties()
    users = UserManager.load_users()

    visible_properties =
      case role do
        r when r in ["vendedor", "arrendador"] ->
          Enum.filter(properties, &(&1.owner == username))

        _ ->
          Enum.filter(properties, &(&1.status == :available))
      end

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
          %{
            total: length(visible_properties),
            available: length(visible_properties),
            sold: nil,
            rented: nil,
            total_users: nil
          }
      end

    ranking = UserManager.ranking() |> Enum.take(5)
    _ = users

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

    {:ok,
     assign(socket,
       username: username,
       role: role,
       stats: stats,
       by_city: by_city,
       by_type: by_type,
       ranking: ranking,
       properties: Enum.take(visible_properties, 5)
     )}
  end

  def render(assigns) do
    ~H"""
    <div style="min-height:100vh; background:#f0f2f5; font-family:sans-serif;">

      <nav style="background:#1a1a2e; padding:1rem 2rem; display:flex; justify-content:space-between; align-items:center;">
        <span style="color:white; font-size:1.25rem; font-weight:700;">🏠 Inmobiliaria</span>
        <div style="display:flex; gap:1rem; align-items:center;">
          <a href={"/properties?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Propiedades</a>
          <a href={"/chat?user=#{@username}&role=#{@role}"} style="color:#a5b4fc; text-decoration:none; font-weight:500;">Chat</a>
          <a href="/" style="color:#f87171; text-decoration:none; font-weight:500;">Salir</a>
        </div>
      </nav>

      <div style="padding:2rem; max-width:1200px; margin:0 auto;">

        <h1 style="color:#1a1a2e; margin-bottom:0.25rem;">📊 Dashboard</h1>
        <p style="color:#888; margin-bottom:2rem;">
          Bienvenido, <strong><%= @username %></strong> ·
          <span style={"color:#{role_color(@role)}; font-weight:600; text-transform:capitalize;"}><%= @role %></span>
        </p>

        <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(180px, 1fr)); gap:1rem; margin-bottom:2rem;">
          <div style="background:white; padding:1.5rem; border-radius:12px; box-shadow:0 2px 8px rgba(0,0,0,0.08); border-left:4px solid #4f46e5;">
            <div style="font-size:2rem; font-weight:700; color:#4f46e5;"><%= @stats.total %></div>
            <div style="color:#666; font-size:0.875rem; margin-top:0.25rem;">
              <%= if @role in ["vendedor", "arrendador"], do: "Mis Propiedades", else: "Disponibles" %>
            </div>
          </div>
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
        </div>

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
              <%= if length(@ranking) > 0 do %>
                <div style="margin-top:0.5rem;">
                  <h4 style="margin:0 0 0.75rem; color:#1a1a2e; font-size:0.9rem;">🏆 Top Ranking</h4>
                  <%= for {user, idx} <- Enum.with_index(@ranking, 1) do %>
                    <div style="display:flex; align-items:center; gap:0.5rem; padding:0.4rem 0; border-bottom:1px solid #f0f0f0; font-size:0.85rem;">
                      <span><%= medal(idx) %></span>
                      <span style="flex:1; color:#1a1a2e;"><%= user.username %></span>
                      <span style="color:#f59e0b; font-weight:600;"><%= user.points %> pts</span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_color(:available), do: "#16a34a"
  defp status_color(:sold), do: "#dc2626"
  defp status_color(:rented), do: "#f59e0b"
  defp status_color(_), do: "#888"

  defp status_label(:available), do: "Disponible"
  defp status_label(:sold), do: "Vendida"
  defp status_label(:rented), do: "Arrendada"
  defp status_label(other), do: to_string(other)

  defp medal(1), do: "🥇"
  defp medal(2), do: "🥈"
  defp medal(3), do: "🥉"
  defp medal(_), do: "👤"

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
