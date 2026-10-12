# helpers/flash_helpers.rb


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

  # Devuelve el nombre de la entidad vinculada (cliente, lead, oportunidad)
  def cargar_entidad(tipo, id)
    return nil unless tipo && id

    case tipo
    when "cliente"
      DB[:clientes].where(id: id).get(:nombre)
    when "lead"
      row = DB[:leads].where(id: id).first
      row ? (row[:empresa] || row[:nombre]) : nil
    when "oportunidad"
      DB[:oportunidades].where(id: id).get(:titulo)
    end
  end
end