defmodule Inmobiliaria.Users.UserManager do
  alias Inmobiliaria.Persistence
  # =========================
  # CONNECT
  # =========================

  def connect(username, password, role) do
    users =
      load_users()

    case Enum.find(users, fn u ->
           u.username == username
         end) do
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
  # LOGIN
  # =========================

  def login(username, password) do
    users =
      load_users()

    case Enum.find(users, fn u ->
           u.username == username and
             u.password == password
         end) do
      nil ->
        {:error, "Credenciales inválidas"}

      user ->
        {:ok, user}
    end
  end

  # =========================
  # REGISTER
  # =========================

  def register(username, password, role) do
    cond do
      String.trim(username) == "" ->
        {:error, "El usuario es obligatorio"}

      String.trim(password) == "" ->
        {:error, "La contraseña es obligatoria"}

      true ->
        users =
          load_users()

        exists? =
          Enum.any?(users, fn user ->
            user.username == username
          end)

        if exists? do
          {:error, "El usuario ya existe"}
        else
          user = %{
            username: username,
            password: password,
            role: role,
            points: 0
          }

          save_user(user)

          {:ok, user}
        end
    end
  end

  # =========================
  # LOAD USERS
  # =========================

  def load_users do
    Persistence.load_users()
  end

  # =========================
  # SAVE USER
  # =========================

  def save_user(user) do
    Persistence.save_user(user)
  end

  # =========================
  # ADD POINTS
  # =========================

  def add_points(username, points) do
    users =
      load_users()

    updated_users =
      Enum.map(users, fn user ->
        if user.username == username do
          %{
            user
            | points: user.points + points
          }
        else
          user
        end
      end)

    rewrite_users(updated_users)
  end

  # =========================
  # REWRITE USERS
  # =========================

  def rewrite_users(users) do
    Persistence.rewrite_users(users)
  end

  # =========================
  # DISCONNECT
  # =========================

  def disconnect(username) do
    users =
      load_users()

    case Enum.find(users, fn u ->
           u.username == username
         end) do
      nil ->
        {:error, "Usuario no encontrado"}

      _user ->
        {:ok, "#{username} desconectado"}
    end
  end

  # =========================
  # GET SCORE
  # =========================

  def get_score(username) do
    users =
      load_users()

    case Enum.find(users, fn u ->
           u.username == username
         end) do
      nil ->
        {:error, "Usuario no encontrado"}

      user ->
        {:ok, user.points}
    end
  end

  # =========================
  # RANKING
  # =========================

  def ranking do
    load_users()
    |> Enum.sort_by(fn user ->
      -user.points
    end)
  end
end
