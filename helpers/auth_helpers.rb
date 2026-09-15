# helpers/auth_helpers.rb

helpers do
  def authenticated?
    !session[:user_id].nil?
  end

  def current_user
    return nil unless authenticated?
    DB[:usuarios].where(id: session[:user_id]).first
  end

  def require_login
    redirect "/login" unless authenticated?
  end

  def current_user_name
    user = current_user
    user ? (user[:nombre] || user[:usuario] || "Usuario") : "Usuario"
  end

  # ✅ AGREGA ESTO: Verifica si la ruta actual coincide para activar el menú
  def current_page?(path)
    request.path == path || (@current_page && @current_page.to_s == path.to_s)
  end
end