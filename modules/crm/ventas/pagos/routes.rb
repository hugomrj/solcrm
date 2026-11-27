# modules/crm/ventas/pagos/routes.rb

class PagosRoutes < BaseApp
  METODOS = VentasHelpers::METODOS_PAGO

  before do
    if request.path_info.start_with?("/ventas/pagos")
      require_login
      halt 403, "Sin permiso para acceder a Pagos" unless puede?(:pagos)
    end
  end

  # --- Listado ---
  get "/ventas/pagos" do
    @current_page = "pagos"
    @page_title   = "Pagos"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:pagos)

    if METODOS.include?(params[:metodo])
      dataset = dataset.where(metodo: params[:metodo])
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:referencia, patron) |
        Sequel.ilike(:notas, patron)
      )
    end

    @pagos = dataset.order(Sequel.desc(:fecha), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)

    @facturas_por_id = cargar_por_id(:facturas, @pagos.map { |p| p[:factura_id] })
    @clientes_por_id = cargar_por_id(:clientes, @pagos.map { |p| p[:cliente_id] })
    @filtros = { q: q, metodo: params[:metodo] }

    erb :"crm/ventas/pagos/index"
  end

  # --- Form alta (ruta estática antes que /:id) ---
  get "/ventas/pagos/nuevo" do
    @current_page = "pagos"
    @page_title   = "Registrar pago"
    @pago         = nil
    @factura_id   = params[:factura_id]
    @origen       = params[:origen]
    cargar_opciones_form

    # Si venimos desde el botón de una factura, la fijamos y precargamos el saldo
    if @factura_id && !@factura_id.to_s.empty?
      @factura_seleccionada = @facturas_abiertas.find { |f| f[:id].to_s == @factura_id.to_s }
      @saldo_seleccionado   = @factura_seleccionada ? saldo_factura(@factura_seleccionada) : nil
    end

    erb :"crm/ventas/pagos/nuevo"
  end

  # --- Ver detalle ---
  get "/ventas/pagos/:id" do
    @current_page = "pagos"
    @pago = tenant_db(:pagos).where(id: params[:id]).first
    halt 404, "Pago no encontrado" unless @pago

    @factura = @pago[:factura_id] ? tenant_db(:facturas).where(id: @pago[:factura_id]).first : nil
    @cliente = tenant_db(:clientes).where(id: @pago[:cliente_id]).first
    @page_title = "Pago ##{@pago[:id]}"

    erb :"crm/ventas/pagos/ver"
  end

  # --- Crear ---
  post "/ventas/pagos" do
    factura = tenant_db(:facturas).where(id: params[:factura_id].to_i).first
    unless factura
      set_flash(:error, "Elegí una factura")
      redirect t("/ventas/pagos/nuevo")
    end

    if %w[borrador anulada].include?(factura[:estado])
      set_flash(:error, "Solo se pueden cobrar facturas emitidas")
      redirect t("/ventas/pagos/nuevo")
    end

    monto = params[:monto].to_s.tr(",", ".").to_f

    if monto <= 0
      set_flash(:error, "El monto debe ser mayor a cero")
      redirect t("/ventas/pagos/nuevo?factura_id=#{factura[:id]}#{query_origen}")
    end

    saldo = saldo_factura(factura)
    if monto > saldo + 0.009
      set_flash(:error, "El monto supera el saldo pendiente (₲ #{number_with_delimiter(saldo)})")
      redirect t("/ventas/pagos/nuevo?factura_id=#{factura[:id]}#{query_origen}")
    end

    metodo     = METODOS.include?(params[:metodo]) ? params[:metodo] : METODOS.first
    fecha      = params[:fecha].to_s.strip
    referencia = params[:referencia].to_s.strip
    notas      = params[:notas].to_s.strip

    DB[:pagos].insert(
      tenant_id:  current_tenant_id,
      factura_id: factura[:id],
      cliente_id: factura[:cliente_id],
      fecha:      fecha.empty? ? Date.today : fecha,
      monto:      monto.round(2),
      metodo:     metodo,
      referencia: referencia.empty? ? nil : referencia,
      notas:      notas.empty? ? nil : notas
    )

    recalcular_estado_factura(factura[:id])

    set_flash(:success, "Pago de ₲ #{number_with_delimiter(monto)} registrado en la factura #{factura[:numero]}")
    # Si el circuito arrancó en "nueva factura", volvemos al detalle marcado
    # para ofrecer "Nueva factura" y encadenar la siguiente.
    redirect t("/ventas/facturas/#{factura[:id]}#{params[:origen] == 'factura' ? '?origen=factura' : ''}")
  end

  # ============================================================
  # Helpers
  # ============================================================
  helpers do
    # Conserva el flag ?origen=factura al volver al formulario por un error
    def query_origen
      params[:origen] == "factura" ? "&origen=factura" : ""
    end

    def cargar_opciones_form
      @facturas_abiertas = facturas_con_saldo(%w[emitida pagada])
      @clientes_por_id   = cargar_por_id(:clientes, @facturas_abiertas.map { |f| f[:cliente_id] })
    end
  end
end
