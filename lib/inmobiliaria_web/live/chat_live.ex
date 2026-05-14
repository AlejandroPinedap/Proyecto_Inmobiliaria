defmodule InmobiliariaWeb.ChatLive do
  use InmobiliariaWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Chat</h1>
    """
  end
end
