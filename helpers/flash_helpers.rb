# helpers/flash_helpers.rb

module FlashHelpers
  def set_flash(type, message)
    session[:flash] = { type: type.to_sym, message: message }
  end

  def render_flash
    flash = session.delete(:flash)
    return "" unless flash

    @flash_type    = flash[:type]
    @flash_message = flash[:message]

    erb :"layout/partials/_flash", layout: false
  end
end