# modules/crm/ventas/facturas/routes.rb

class FacturasRoutes < BaseApp
  ESTADOS = %w[borrador emitida pagada anulada].freeze

  # Intercepta la ruta
  before do
    if request.path_info.start_with?("/ventas/facturas")
      require_login
      halt 403, "Sin permiso para acceder a Facturas" unless puede?(:facturas)
    end
  end

  # --- Listado ---
  get "/ventas/facturas" do
    @current_page = "facturas"
    @page_title   = "Facturas"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:facturas)

    if ESTADOS.include?(params[:estado])
      dataset = dataset.where(estado: params[:estado])
    end

    if params[:cliente_id] && !params[:cliente_id].to_s.empty?
      dataset = dataset.where(cliente_id: params[:cliente_id].to_i)
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:numero, patron) |
        Sequel.ilike(:notas,  patron)
      )
    end

    @facturas = dataset.order(Sequel.desc(:fecha), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
    @clientes = tenant_db(:clientes).where(activo: true).order(:nombre).all
    @filtros  = { q: q, estado: params[:estado], cliente_id: params[:cliente_id] }

    erb :"crm/ventas/facturas/index"
  end

  # --- Form alta ---
  get "/ventas/facturas/nuevo" do
    @current_page = "facturas"
    @page_title   = "Nueva factura"
    @factura      = nil
    @items        = []
    cargar_opciones_form
    erb :"crm/ventas/facturas/nuevo"
  end





  # --- Generar PDF ---
  get "/ventas/facturas/:id/pdf" do
    factura = tenant_db(:facturas).where(id: params[:id]).first
    halt 404, "Factura no encontrada" unless factura

    cliente = tenant_db(:clientes).where(id: factura[:cliente_id]).first
    # facturas_items NO tiene tenant_id: se accede por FK de una factura ya filtrada por tenant
    items   = DB[:facturas_items].where(factura_id: factura[:id]).order(:id).all

    content_type "application/pdf"
    headers "Content-Disposition" => "inline; filename=\"Factura_#{factura[:numero]}.pdf\""
    factura_pdf(factura, cliente, items)
  end




  # --- Ver detalle ---
  get "/ventas/facturas/:id" do
    @current_page = "facturas"
    @factura = tenant_db(:facturas).where(id: params[:id]).first
    halt 404, "Factura no encontrada" unless @factura

    @cliente = tenant_db(:clientes).where(id: @factura[:cliente_id]).first
    @items   = DB[:facturas_items].where(factura_id: @factura[:id]).order(:id).all
    @pagos   = tenant_db(:pagos).where(factura_id: @factura[:id]).order(Sequel.asc(:fecha)).all
    @notas   = tenant_db(:notas_credito).where(factura_id: @factura[:id]).order(Sequel.asc(:fecha)).all
    @page_title = "Factura #{@factura[:numero]}"

    erb :"crm/ventas/facturas/ver"
  end

  # --- Crear ---
  post "/ventas/facturas" do
    cliente_id  = params[:cliente_id].to_s.strip
    fecha       = params[:fecha].to_s.strip
    vencimiento = params[:vencimiento].to_s.strip
    estado      = params[:estado].to_s.strip
    notas       = params[:notas].to_s.strip
    items       = parsear_items(params[:items])

    if cliente_id.empty?
      set_flash(:error, "Elegí un cliente")
      redirect t("/ventas/facturas/nuevo")
    end

    if items.empty?
      set_flash(:error, "Agregá al menos un ítem")
      redirect t("/ventas/facturas/nuevo")
    end

    estado = "borrador" unless ESTADOS.include?(estado)
    numero = siguiente_numero

    subtotal, impuestos, total = calcular_totales(items)

    factura_id = nil
    DB.transaction do
      factura_id = DB[:facturas].insert(
        tenant_id:   current_tenant_id,
        numero:      numero,
        cliente_id:  cliente_id.to_i,
        fecha:       fecha.empty? ? Date.today : fecha,
        vencimiento: vencimiento.empty? ? nil : vencimiento,
        subtotal:    subtotal,
        impuestos:   impuestos,
        total:       total,
        estado:      estado,
        notas:       notas.empty? ? nil : notas
      )

      items.each do |it|
        DB[:facturas_items].insert(
          factura_id:  factura_id,
          articulo_id: it[:articulo_id],
          descripcion: it[:descripcion],
          cantidad:    it[:cantidad],
          precio:      it[:precio],
          total:       it[:total]
        )
      end
    end

    if estado == "emitida"
      generar_movimientos_factura(tenant_db(:facturas).where(id: factura_id).first)
      set_flash(:success, "Factura #{numero} creada. Registrá el cobro:")
      redirect t("/ventas/pagos/nuevo?factura_id=#{factura_id}&origen=factura")
    else
      set_flash(:success, "Factura #{numero} creada")
      redirect t("/ventas/facturas/#{factura_id}")
    end
  end

  # --- Form edición (solo borrador) ---
  get "/ventas/facturas/:id/editar" do
    @current_page = "facturas"
    @factura = tenant_db(:facturas).where(id: params[:id]).first
    halt 404, "Factura no encontrada" unless @factura

    if @factura[:estado] != "borrador"
      set_flash(:error, "Solo se pueden editar facturas en borrador")
      redirect t("/ventas/facturas/#{@factura[:id]}")
    end

    @page_title = "Editar factura #{@factura[:numero]}"
    @items = DB[:facturas_items].where(factura_id: @factura[:id]).order(:id).all
    cargar_opciones_form
    erb :"crm/ventas/facturas/editar"
  end

  # --- Actualizar ---
  post "/ventas/facturas/:id" do
    factura = tenant_db(:facturas).where(id: params[:id]).first
    halt 404, "Factura no encontrada" unless factura

    if factura[:estado] != "borrador"
      set_flash(:error, "Solo se pueden editar facturas en borrador")
      redirect t("/ventas/facturas/#{factura[:id]}")
    end

    cliente_id  = params[:cliente_id].to_s.strip
    fecha       = params[:fecha].to_s.strip
    vencimiento = params[:vencimiento].to_s.strip
    notas       = params[:notas].to_s.strip
    items       = parsear_items(params[:items])

    if cliente_id.empty? || items.empty?
      set_flash(:error, "Cliente e ítems son obligatorios")
      redirect t("/ventas/facturas/#{factura[:id]}/editar")
    end

    subtotal, impuestos, total = calcular_totales(items)

    DB.transaction do
      DB[:facturas].where(id: factura[:id]).update(
        cliente_id:  cliente_id.to_i,
        fecha:       fecha.empty? ? factura[:fecha] : fecha,
        vencimiento: vencimiento.empty? ? nil : vencimiento,
        subtotal:    subtotal,
        impuestos:   impuestos,
        total:       total,
        notas:       notas.empty? ? nil : notas,
        updated_at:  Sequel::CURRENT_TIMESTAMP
      )

      DB[:facturas_items].where(factura_id: factura[:id]).delete
      items.each do |it|
        DB[:facturas_items].insert(
          factura_id:  factura[:id],
          articulo_id: it[:articulo_id],
          descripcion: it[:descripcion],
          cantidad:    it[:cantidad],
          precio:      it[:precio],
          total:       it[:total]
        )
      end
    end

    set_flash(:success, "Factura actualizada")
    redirect t("/ventas/facturas/#{factura[:id]}")
  end

  # --- Cambiar estado ---
  post "/ventas/facturas/:id/estado" do
    factura = tenant_db(:facturas).where(id: params[:id]).first
    halt 404, "Factura no encontrada" unless factura

    nuevo = params[:estado].to_s
    unless ESTADOS.include?(nuevo)
      halt 400, "Estado inválido"
    end

    DB[:facturas].where(id: factura[:id]).update(
      estado:     nuevo,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    # Al emitir, se descuenta el stock de los artículos vendidos
    generar_movimientos_factura(tenant_db(:facturas).where(id: factura[:id]).first) if nuevo == "emitida"

    set_flash(:success, "Factura marcada como #{nuevo}")
    redirect t("/ventas/facturas/#{factura[:id]}")
  end

  # --- Anular ---
  post "/ventas/facturas/:id/eliminar" do
    factura = tenant_db(:facturas).where(id: params[:id]).first
    halt 404, "Factura no encontrada" unless factura

    if factura[:estado] == "pagada"
      set_flash(:error, "No se puede anular una factura pagada")
      redirect t("/ventas/facturas")
    end

    DB[:facturas].where(id: factura[:id]).update(
      estado:     "anulada",
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Factura #{factura[:numero]} anulada")
    redirect t("/ventas/facturas")
  end

  # ============================================================
  # Helpers
  # ============================================================
  helpers do
    def cargar_opciones_form
      @clientes  = tenant_db(:clientes).where(activo: true).order(:nombre).all
      @articulos = tenant_db(:articulos).where(activo: true).order(:nombre).all
    end

    def siguiente_numero
      ultimo = tenant_db(:facturas).order(Sequel.desc(:id)).get(:numero)
      n = ultimo.to_s[/\d+/].to_i + 1
      "FAC-#{n.to_s.rjust(6, '0')}"
    end

    def parsear_items(raw)
      return [] if raw.nil?
      lista = raw.is_a?(Hash) ? raw.values : raw
      lista.map do |it|
        desc  = it[:descripcion].to_s.strip
        cant  = it[:cantidad].to_f
        prec  = it[:precio].to_f
        next if desc.empty? || cant <= 0
        {
          articulo_id: it[:articulo_id].to_s.empty? ? nil : it[:articulo_id].to_i,
          descripcion: desc,
          cantidad:    cant,
          precio:      prec,
          total:       (cant * prec).round(2)
        }
      end.compact
    end

    def calcular_totales(items)
      subtotal  = items.sum { |i| i[:total] }.round(2)
      impuestos = (subtotal * 0.10).round(2)
      total     = (subtotal + impuestos).round(2)
      [subtotal, impuestos, total]
    end
  end
end