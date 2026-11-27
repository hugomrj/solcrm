# helpers/inventario_helpers.rb
#
# El stock NO está materializado en articulos: se calcula sumando movimientos.
#   entrada -> suma
#   salida  -> resta
#   ajuste  -> suma el delta (puede ser negativo)

module InventarioHelpers
  TIPOS_MOVIMIENTO = %w[entrada salida ajuste].freeze

  # Expresión SQL del delta de cada movimiento
  def delta_movimiento
    Sequel.case(
      { { tipo: %w[entrada ajuste] } => Sequel[:cantidad] },
      Sequel[:cantidad] * -1
    )
  end

  # { articulo_id => stock } para un conjunto de artículos
  def stock_por_articulo(articulo_ids)
    ids = articulo_ids.compact.uniq
    return {} if ids.empty?

    tenant_db(:stock_movimientos)
      .where(articulo_id: ids)
      .select(:articulo_id, Sequel.function(:sum, delta_movimiento).as(:stock))
      .group(:articulo_id)
      .all
      .each_with_object({}) { |row, hash| hash[row[:articulo_id]] = row[:stock].to_f }
  end

  # Stock actual de un artículo
  def stock_articulo(articulo_id)
    return 0.0 if articulo_id.nil?

    total = tenant_db(:stock_movimientos)
      .where(articulo_id: articulo_id)
      .sum(delta_movimiento)

    total.to_f
  end

  # Genera las salidas de una factura emitida. Idempotente por referencia.
  def generar_movimientos_factura(factura)
    return if factura.nil?

    ref = "FAC:#{factura[:numero]}"
    return if tenant_db(:stock_movimientos).where(referencia: ref).count > 0

    DB[:facturas_items].where(factura_id: factura[:id]).all.each do |item|
      next unless item[:articulo_id]

      articulo = tenant_db(:articulos).where(id: item[:articulo_id]).first
      next unless articulo && articulo[:tipo] == "producto"

      registrar_movimiento(
        articulo_id: articulo[:id],
        tipo:        "salida",
        cantidad:    item[:cantidad].to_f,
        referencia:  ref,
        motivo:      "Venta #{factura[:numero]}"
      )
    end
  end

  # Genera las entradas de una orden de compra recibida. Idempotente por referencia.
  def generar_movimientos_orden(orden)
    return if orden.nil?

    ref = "OC:#{orden[:numero]}"
    return if tenant_db(:stock_movimientos).where(referencia: ref).count > 0

    DB[:ordenes_compra_items].where(orden_compra_id: orden[:id]).all.each do |item|
      next unless item[:articulo_id]

      articulo = tenant_db(:articulos).where(id: item[:articulo_id]).first
      next unless articulo && articulo[:tipo] == "producto"

      registrar_movimiento(
        articulo_id: articulo[:id],
        tipo:        "entrada",
        cantidad:    item[:cantidad].to_f,
        referencia:  ref,
        motivo:      "Compra #{orden[:numero]}"
      )
    end
  end

  # Registra un movimiento y devuelve su id
  def registrar_movimiento(articulo_id:, tipo:, cantidad:, referencia: nil, motivo: nil)
    DB[:stock_movimientos].insert(
      tenant_id:  current_tenant_id,
      articulo_id: articulo_id,
      tipo:       tipo,
      cantidad:   cantidad,
      referencia: referencia.to_s.empty? ? nil : referencia,
      motivo:     motivo.to_s.empty? ? nil : motivo,
      usuario_id: current_user ? current_user[:id] : nil
    )
  end
end
