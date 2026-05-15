defmodule InmobiliariaWeb.LoginLive do
  use InmobiliariaWeb, :live_view

  alias Inmobiliaria.Users.UserManager

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       tab: :login,
       error: nil,
       success: nil
     )}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    current_tab =
      case tab do
        "login" -> :login
        "register" -> :register
        _ -> :login
      end

    {:noreply, assign(socket, tab: current_tab, error: nil, success: nil)}
  end

  def handle_event("login", %{"username" => username, "password" => password}, socket) do
    case UserManager.login(username, password) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, %{username: user.username, role: user.role})
         |> push_navigate(to: "/dashboard?user=#{user.username}&role=#{user.role}")}

      {:error, msg} ->
        {:noreply, assign(socket, error: msg, success: nil)}
    end
  end

  def handle_event(
        "register",
        %{"username" => username, "password" => password, "role" => role},
        socket
      ) do
    case UserManager.register(username, password, role) do
      {:ok, _user} ->
        {:noreply,
         assign(socket,
           success: "Usuario registrado correctamente. Ahora puedes iniciar sesión.",
           tab: :login,
           error: nil
         )}

      {:error, msg} ->
        {:noreply, assign(socket, error: msg, success: nil)}
    end
  end

  def render(assigns) do
    ~H"""
    <div style="min-height:100vh; display:flex; align-items:center; justify-content:center; background:#f0f2f5;">
      <div style="background:white; padding:2rem; border-radius:12px; box-shadow:0 4px 20px rgba(0,0,0,0.1); width:100%; max-width:400px;">

        <h1 style="text-align:center; margin-bottom:1.5rem; color:#1a1a2e;">🏠 Inmobiliaria</h1>

        <div style="display:flex; margin-bottom:1.5rem; border-bottom:2px solid #eee;">
          <button type="button" phx-click="switch_tab" phx-value-tab="login"
            style={"flex:1; padding:0.75rem; border:none; cursor:pointer; font-weight:600; background:transparent; border-bottom:#{if @tab == :login, do: "2px solid #4f46e5", else: "none"}; color:#{if @tab == :login, do: "#4f46e5", else: "#999"};"}>
            Iniciar Sesión
          </button>
          <button type="button" phx-click="switch_tab" phx-value-tab="register"
            style={"flex:1; padding:0.75rem; border:none; cursor:pointer; font-weight:600; background:transparent; border-bottom:#{if @tab == :register, do: "2px solid #4f46e5", else: "none"}; color:#{if @tab == :register, do: "#4f46e5", else: "#999"};"}>
            Registrarse
          </button>
        </div>

        <%= if @error do %>
          <div style="background:#fee2e2; color:#dc2626; padding:0.75rem; border-radius:8px; margin-bottom:1rem;">
            ⚠️ <%= @error %>
          </div>
        <% end %>

        <%= if @success do %>
          <div style="background:#dcfce7; color:#16a34a; padding:0.75rem; border-radius:8px; margin-bottom:1rem;">
            ✅ <%= @success %>
          </div>
        <% end %>

        <%= if @tab == :login do %>
          <form phx-submit="login">
            <div style="margin-bottom:1rem;">
              <label style="display:block; margin-bottom:0.25rem; color:#555; font-size:0.875rem;">Usuario</label>
              <input type="text" name="username"
                style="width:100%; padding:0.75rem; border:1px solid #ddd; border-radius:8px; font-size:1rem; box-sizing:border-box;"
                placeholder="Tu nombre de usuario"/>
            </div>
            <div style="margin-bottom:1.5rem;">
              <label style="display:block; margin-bottom:0.25rem; color:#555; font-size:0.875rem;">Contraseña</label>
              <input type="password" name="password"
                style="width:100%; padding:0.75rem; border:1px solid #ddd; border-radius:8px; font-size:1rem; box-sizing:border-box;"
                placeholder="Tu contraseña"/>
            </div>
            <button type="submit"
              style="width:100%; padding:0.75rem; background:#4f46e5; color:white; border:none; border-radius:8px; font-size:1rem; font-weight:600; cursor:pointer;">
              Entrar
            </button>
          </form>
        <% else %>
          <form phx-submit="register">
            <div style="margin-bottom:1rem;">
              <label style="display:block; margin-bottom:0.25rem; color:#555; font-size:0.875rem;">Usuario</label>
              <input type="text" name="username"
                style="width:100%; padding:0.75rem; border:1px solid #ddd; border-radius:8px; font-size:1rem; box-sizing:border-box;"
                placeholder="Tu nombre de usuario"/>
            </div>
            <div style="margin-bottom:1rem;">
              <label style="display:block; margin-bottom:0.25rem; color:#555; font-size:0.875rem;">Contraseña</label>
              <input type="password" name="password"
                style="width:100%; padding:0.75rem; border:1px solid #ddd; border-radius:8px; font-size:1rem; box-sizing:border-box;"
                placeholder="Tu contraseña"/>
            </div>
            <div style="margin-bottom:1.5rem;">
              <label style="display:block; margin-bottom:0.25rem; color:#555; font-size:0.875rem;">Rol</label>
              <select name="role"
              style="width:100%; padding:0.75rem; border:1px solid #ddd; border-radius:8px; font-size:1rem; box-sizing:border-box;">
              <option value="cliente">Cliente</option>
              <option value="vendedor">Vendedor</option>
              <option value="arrendador">Arrendador</option>
              </select>
            </div>
            <button type="submit"
              style="width:100%; padding:0.75rem; background:#4f46e5; color:white; border:none; border-radius:8px; font-size:1rem; font-weight:600; cursor:pointer;">
              Crear cuenta
            </button>
          </form>
        <% end %>

      </div>
    </div>
    """
  end
end
