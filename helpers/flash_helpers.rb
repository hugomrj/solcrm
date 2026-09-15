# helpers/flash_helpers.rb

helpers do
  # Guarda el mensaje en la sesión para la siguiente petición
  def set_flash(type, message)
    session[:flash] = { type: type.to_sym, message: message }
  end

  # Lee, renderiza y AUTODESTRUYE el mensaje
  def render_flash
    flash = session.delete(:flash)
    return "" unless flash

    @flash_type = flash[:type]
    @flash_message = flash[:message]
    
    # Renderiza el parcial
    erb :"layout/partials/_flash", layout: false
  end
end