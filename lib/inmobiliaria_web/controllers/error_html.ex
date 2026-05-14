defmodule InmobiliariaWeb.ErrorHTML do
  use Phoenix.Component

  def render("404.html", _assigns) do
    "Página no encontrada"
  end

  def render("500.html", _assigns) do
    "Error interno del servidor"
  end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
