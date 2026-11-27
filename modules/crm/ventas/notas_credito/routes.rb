# modules/crm/ventas/notas_credito/routes.rb

class NotasCreditoRoutes < BaseApp
  before do
    if request.path_info.start_with?("/ventas/notas_credito")
      require_login
      halt 403, "Sin permiso para acceder a Notas de crédito" unless puede?(:notas_credito)
    end
  end

  # --- Listado ---
  get "/ventas/notas_credito" do
    @current_page = "notas_credito"
    @page_title   = "Notas de crédito"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:notas_credito)

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:numero, patron) |
        Sequel.ilike(:motivo, patron)
      )
    end

    @notas = dataset.order(Sequel.desc(:fecha), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)

    @facturas_por_id = cargar_por_id(:facturas, @notas.map { |n| n[:factura_id] })
    @clientes_por_id = cargar_por_id(:clientes, @notas.map { |n| n[:cliente_id] })
    @filtros = { q: q }

    erb :"crm/ventas/notas_credito/index"
  end

  # --- Form alta (ruta estática antes que /:id) ---
  get "/ventas/notas_credito/nuevo" do
    @current_page = "notas_credito"
    @page_title   = "Nueva nota de crédito"
    @nota         = nil
    @factura_id   = params[:factura_id]
    cargar_opciones_form
    erb :"crm/ventas/notas_credito/nuevo"
  end

  # --- Ver detalle ---
  get "/ventas/notas_credito/:id" do
    @current_page = "notas_credito"
    @nota = tenant_db(:notas_credito).where(id: params[:id]).first
    halt 404, "Nota de crédito no encontrada" unless @nota

    @factura = @nota[:factura_id] ? tenant_db(:facturas).where(id: @nota[:factura_id]).first : nil
    @cliente = tenant_db(:clientes).where(id: @nota[:cliente_id]).first
    @page_title = "Nota de crédito #{@nota[:numero]}"

    erb :"crm/ventas/notas_credito/ver"
  end

  # --- Crear ---
  post "/ventas/notas_credito" do
    factura = tenant_db(:facturas).where(id: params[:factura_id].to_i).first
    unless factura
      set_flash(:error, "Elegí una factura")
      redirect t("/ventas/notas_credito/nuevo")
    end

    if factura[:estado] == "anulada"
      set_flash(:error, "No se puede acreditar una factura anulada")
      redirect t("/ventas/notas_credito/nuevo")
    end

    if factura[:estado] == "borrador"
      set_flash(:error, "Emití la factura antes de acreditarla")
      redirect t("/ventas/notas_credito/nuevo")
    end

    monto = params[:monto].to_s.tr(",", ".").to_f

    if monto <= 0
      set_flash(:error, "El monto debe ser mayor a cero")
      redirect t("/ventas/notas_credito/nuevo?factura_id=#{factura[:id]}")
    end

    saldo = saldo_factura(factura)
    if monto > saldo + 0.009
      set_flash(:error, "El monto supera el saldo pendiente (₲ #{number_with_delimiter(saldo)})")
      redirect t("/ventas/notas_credito/nuevo?factura_id=#{factura[:id]}")
    end

    fecha  = params[:fecha].to_s.strip
    motivo = params[:motivo].to_s.strip
    numero = siguiente_numero

    DB[:notas_credito].insert(
      tenant_id:  current_tenant_id,
      numero:     numero,
      cliente_id: factura[:cliente_id],
      factura_id: factura[:id],
      fecha:      fecha.empty? ? Date.today : fecha,
      monto:      monto.round(2),
      motivo:     motivo.empty? ? nil : motivo
    )

    recalcular_estado_factura(factura[:id])

    set_flash(:success, "Nota de crédito #{numero} registrada por ₲ #{number_with_delimiter(monto)}")
    redirect t("/ventas/facturas/#{factura[:id]}")
  end

  # ============================================================
  # Helpers
  # ============================================================
  helpers do
    def cargar_opciones_form
      @facturas_abiertas = facturas_con_saldo(%w[emitida pagada])
      @clientes_por_id   = cargar_por_id(:clientes, @facturas_abiertas.map { |f| f[:cliente_id] })
    end

    def siguiente_numero
      ultimo = tenant_db(:notas_credito).order(Sequel.desc(:id)).get(:numero)
      n = ultimo.to_s[/\d+/].to_i + 1
      "NC-#{n.to_s.rjust(6, '0')}"
    end
  end
end
