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
      </head>
      <body>
        <%= @inner_content %>
        <script>
          var phoenixScript = document.createElement('script');
          phoenixScript.src = 'https://cdn.jsdelivr.net/npm/phoenix@1.7.14/priv/static/phoenix.min.js';
          phoenixScript.onload = function() {
            var lvScript = document.createElement('script');
            lvScript.src = 'https://cdn.jsdelivr.net/npm/phoenix_live_view@1.1.30/priv/static/phoenix_live_view.min.js';
            lvScript.onload = function() {
              var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
              var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
                params: {_csrf_token: csrfToken}
              });
              liveSocket.connect();
              window.liveSocket = liveSocket;
            };
            document.head.appendChild(lvScript);
          };
          document.head.appendChild(phoenixScript);
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
