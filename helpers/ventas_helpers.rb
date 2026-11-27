# helpers/ventas_helpers.rb
#
# Lógica compartida de cobranza: saldo de una factura, estado automático
# y carga de facturas con saldo pendiente.
#
# Saldo = total factura - pagos - notas de crédito

module VentasHelpers
  METODOS_PAGO = %w[efectivo transferencia cheque tarjeta otro].freeze

  # Suma de los cobros de una factura
  def total_pagado_factura(factura_id)
    return 0.0 if factura_id.nil?
    tenant_db(:pagos).where(factura_id: factura_id).sum(:monto).to_f
  end

  # Suma de las notas de crédito aplicadas a una factura
  def total_notas_factura(factura_id)
    return 0.0 if factura_id.nil?
    tenant_db(:notas_credito).where(factura_id: factura_id).sum(:monto).to_f
  end

  # Lo que falta cobrar de una factura (0 si ya está cubierta)
  def saldo_factura(factura)
    return 0.0 unless factura
    (factura[:total].to_f - total_pagado_factura(factura[:id]) - total_notas_factura(factura[:id])).round(2)
  end

  # Pasa a "pagada" cuando el saldo queda cubierto, y vuelve a "emitida" si no.
  # Nunca toca borradores ni facturas anuladas.
  def recalcular_estado_factura(factura_id)
    factura = tenant_db(:facturas).where(id: factura_id).first
    return unless factura
    return if %w[borrador anulada].include?(factura[:estado])

    nuevo = saldo_factura(factura) <= 0.009 ? "pagada" : "emitida"
    return if factura[:estado] == nuevo

    DB[:facturas].where(id: factura[:id]).update(
      estado:     nuevo,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )
  end

  # Facturas que todavía tienen algo por cobrar
  def facturas_con_saldo(estados = %w[emitida pagada])
    facturas = tenant_db(:facturas).where(estado: estados).order(Sequel.desc(:fecha), Sequel.desc(:id)).all
    return [] if facturas.empty?

    ids    = facturas.map { |f| f[:id] }
    pagado = sumar_por_factura(tenant_db(:pagos), ids)
    notas  = sumar_por_factura(tenant_db(:notas_credito), ids)

    facturas.select do |f|
      saldo = f[:total].to_f - pagado[f[:id]].to_f - notas[f[:id]].to_f
      saldo > 0.009
    end
  end

  # { factura_id => suma } para un conjunto de facturas.
  # OJO: no usar .group(...).sum(...) acá: en esta versión de Sequel el
  # agregado se envuelve en un subselect y Postgres rompe con GroupingError.
  def sumar_por_factura(dataset, factura_ids)
    return {} if factura_ids.empty?

    dataset
      .where(factura_id: factura_ids)
      .select(:factura_id, Sequel.function(:sum, :monto).as(:total))
      .group(:factura_id)
      .all
      .each_with_object({}) { |row, hash| hash[row[:factura_id]] = row[:total].to_f }
  end

  # Carga registros por id y los devuelve como hash { id => row }
  def cargar_por_id(tabla, ids)
    ids = ids.compact.uniq
    return {} if ids.empty?

    tenant_db(tabla).where(id: ids).all.each_with_object({}) { |row, hash| hash[row[:id]] = row }
  end

  # Número listo para un input: sin notación científica (0.15e7) ni ".0" al final.
  # Los NUMERIC de Postgres llegan como BigDecimal y su to_s rompe los <input>.
  def numero_input(valor)
    return "" if valor.nil?

    f = valor.to_f
    f == f.to_i ? f.to_i.to_s : f.to_s
  end
end
