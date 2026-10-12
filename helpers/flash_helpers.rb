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

  def number_with_delimiter(numero)
    return "0" if numero.nil?

    entero = numero.to_f.round
    entero.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
  end
end