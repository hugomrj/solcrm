# modules/usuario/routes.rb


get "/" do
  redirect "/login"
end

get "/login" do
  redirect "/dashboard" if authenticated?
  erb :"usuario/login", layout: false
end

post "/login" do
  usuario = DB[:usuarios]
    .where(usuario: params[:username], activo: true)
    .first

  if usuario && BCrypt::Password.new(usuario[:password_hash]) == params[:password]
    session[:user_id] = usuario[:id]
    
    # ✅ ÉXITO
    set_flash(:success, "¡Bienvenido de nuevo a SolCRM!")
    redirect "/dashboard"
  end

  # ❌ ERROR
  set_flash(:error, "Usuario o contraseña incorrectos")
  redirect "/login"
end

# ✅ Cerrar sesión
get "/logout" do
  session.clear
  set_flash(:success, "Sesión cerrada correctamente")
  redirect "/login"
end