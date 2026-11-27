# helpers/informes_helpers.rb

module InformesHelpers
  MESES_ES = %w[Ene Feb Mar Abr May Jun Jul Ago Sep Oct Nov Dic].freeze

  # Rango de fechas del informe: por defecto, el año en curso hasta hoy.
  def rango_informe
    hoy   = Date.today
    desde = fecha_o_default(params[:desde], Date.new(hoy.year, 1, 1))
    hasta = fecha_o_default(params[:hasta], hoy)
    desde, hasta = hasta, desde if desde > hasta
    [desde, hasta]
  end

  def fecha_o_default(valor, default)
    return default if valor.to_s.strip.empty?
    Date.parse(valor.to_s)
  rescue ArgumentError
    default
  end

  # Lista de claves "YYYY-MM" entre dos fechas (incluye meses sin movimientos)
  def meses_del_rango(desde, hasta)
    meses = []
    cursor = Date.new(desde.year, desde.month, 1)
    while cursor <= hasta
      meses << cursor.strftime("%Y-%m")
      cursor = cursor.next_month
    end
    meses
  end

  # "2026-11" -> "Nov 2026"
  def etiqueta_mes(clave)
    anio, mes = clave.split("-").map(&:to_i)
    "#{MESES_ES[mes - 1]} #{anio}"
  end

  def porcentaje(parte, total)
    return 0.0 if total.to_f <= 0
    ((parte.to_f / total.to_f) * 100).round(1)
  end
end
