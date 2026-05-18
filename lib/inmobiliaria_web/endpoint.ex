defmodule InmobiliariaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :proyecto_inmobiliaria

  @secret_key_base "inmobiliaria_clave_secreta_super_larga_para_cookies_proyecto_2024_ok"

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [
        session: [
          store: :cookie,
          key: "_inmobiliaria_key",
          signing_salt: "inmobiliaria_salt",
          secret_key_base: "inmobiliaria_clave_secreta_super_larga_para_cookies_proyecto_2024_ok",
          same_site: "Lax"
        ]
      ]
    ]

  plug Plug.Static,
  at: "/",
  from: :proyecto_inmobiliaria,
  gzip: false,
  only: ~w(css fonts images js favicon.ico robots.txt)

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  plug Plug.Session,
    store: :cookie,
    key: "_inmobiliaria_key",
    signing_salt: "inmobiliaria_salt",
    same_site: "Lax"

  plug InmobiliariaWeb.Router

  def init(_type, config) do
    {:ok, Keyword.put(config, :secret_key_base, @secret_key_base)}
  end
end
