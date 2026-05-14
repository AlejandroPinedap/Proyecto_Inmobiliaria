defmodule InmobiliariaWeb.Layouts do
  use Phoenix.Component

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="es">
      <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()}/>
        <title>Inmobiliaria</title>
        <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.14/priv/static/phoenix.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@1.1.30/priv/static/phoenix_live_view.min.js"></script>
        <script>
          window.addEventListener("load", function() {
            var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
            var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
              params: {_csrf_token: csrfToken}
            });
            liveSocket.connect();
            window.liveSocket = liveSocket;
          });
        </script>
      </head>
      <body>
        <div id="connection-status" style="display:none; background:#fef3c7; color:#92400e; text-align:center; padding:0.5rem; font-size:0.875rem;">
          ⏳ Conectando...
        </div>
        <%= @inner_content %>
        <script>
          window.addEventListener("phx:page-loading-start", () => {
            document.getElementById("connection-status").style.display = "block";
          });
          window.addEventListener("phx:page-loading-stop", () => {
            document.getElementById("connection-status").style.display = "none";
          });
        </script>
      </body>
    </html>
    """
  end

  def render("app.html", assigns) do
    ~H"""
    <%= @inner_content %>
    """
  end
end
