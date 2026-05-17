import Config

config :proyecto_inmobiliaria, InmobiliariaWeb.Endpoint,
  http: [port: 4000],
  url: [host: "localhost"],
  secret_key_base: "supersecretkey1234567890123456789012345678901234567890123456789012",
  live_view: [signing_salt: "inmobiliaria_salt"],
  server: true,
  render_errors: [formats: [html: InmobiliariaWeb.ErrorHTML]],
  pubsub_server: Inmobiliaria.PubSub

config :proyecto_inmobiliaria, :generators,
  context_app: :proyecto_inmobiliaria

config :phoenix, :json_library, Jason
