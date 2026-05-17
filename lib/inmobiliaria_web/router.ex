defmodule InmobiliariaWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_live_flash
    plug :put_root_layout, html: {InmobiliariaWeb.Layouts, :root}
  end

  scope "/", InmobiliariaWeb do
    pipe_through :browser

    live "/",        LoginLive,     :index
    live "/dashboard", DashboardLive, :index
    live "/properties", PropertiesLive, :index
    live "/chat",    ChatLive,      :index
  end
end
