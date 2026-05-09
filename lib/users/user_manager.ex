defmodule Inmobiliaria.Users.UserManager do

  def connect(username, password, role) do

    users = load_users()

    case Enum.find(users, fn u -> u.username == username end) do

      nil ->

        user = %{
          username: username,
          password: password,
          role: role,
          points: 0
        }

        save_user(user)

        {:ok, "Usuario registrado"}

      user ->

        if user.password == password do
          {:ok, "Login exitoso"}
        else
          {:error, "Contraseña incorrecta"}
        end
    end
  end

  # =========================
  # CARGAR USUARIOS
  # =========================

  def load_users do

    if File.exists?(@file) do

      @file
      |> File.read!()
      |> String.split("
", trim: true)
      |> Enum.map(&parse_user/1)

    else
      []
    end
  end

  # =========================
  # GUARDAR USUARIO
  # =========================

  def save_user(user) do

    line =
      "#{user.username};#{user.password};#{user.role};#{user.points}
"

    File.write!(@file, line, [:append])
  end

  # =========================
  # PARSEAR
  # =========================

  defp parse_user(line) do

    [username, password, role, points] =
      String.split(line, ";")

    %{
      username: username,
      password: password,
      role: role,
      points: String.to_integer(points)
    }
  end
  # =========================
# ACTUALIZAR PUNTOS
# =========================

def add_points(username, points) do

  users =
    load_users()

  updated_users =
    Enum.map(users, fn user ->

      if user.username == username do

        %{user | points: user.points + points}

      else
        user
      end
    end)

  rewrite_users(updated_users)
end

# =========================
# REESCRIBIR ARCHIVO
# =========================

def rewrite_users(users) do

  content =
    Enum.map_join(users, "\n", fn user ->

      "#{user.username};#{user.password};" <>
      "#{user.role};#{user.points}"

    end)

  File.write!(@file, content)
end

# =========================
# RANKING
# =========================

def ranking do

  load_users()
  |> Enum.sort_by(fn user -> -user.points end)
end
end
