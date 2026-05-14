defmodule InmobiliariaWeb do
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {InmobiliariaWeb.Layouts, :app}
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
