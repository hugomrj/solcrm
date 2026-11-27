# modules/crm/compras/ordenes_compra/routes.rb

class OrdenesCompraRoutes < BaseApp
  ESTADOS = %w[borrador emitida recibida anulada].freeze

  before do
    if request.path_info.start_with?("/ordenes_compra")
      require_login
      halt 403, "Sin permiso para acceder a Órdenes de compra" unless puede?(:ordenes_compra)
    end
  end

  # --- Listado ---
  get "/ordenes_compra" do
    @current_page = "ordenes_compra"
    @page_title   = "Órdenes de compra"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:ordenes_compra)

    if ESTADOS.include?(params[:estado])
      dataset = dataset.where(estado: params[:estado])
    end

    if params[:proveedor_id] && !params[:proveedor_id].to_s.empty?
      dataset = dataset.where(proveedor_id: params[:proveedor_id].to_i)
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:numero, patron) |
        Sequel.ilike(:notas,  patron)
      )
    end

    @ordenes = dataset.order(Sequel.desc(:fecha), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
    @proveedores_por_id = cargar_por_id(:proveedores, @ordenes.map { |o| o[:proveedor_id] })
    @proveedores = tenant_db(:proveedores).where(activo: true).order(:nombre).all
    @filtros = { q: q, estado: params[:estado], proveedor_id: params[:proveedor_id] }

    erb :"crm/compras/ordenes_compra/index"
  end

  # --- Form alta ---
  get "/ordenes_compra/nuevo" do
    @current_page = "ordenes_compra"
    @page_title   = "Nueva orden de compra"
    @orden        = nil
    @items        = []
    cargar_opciones_form
    erb :"crm/compras/ordenes_compra/nuevo"
  end

  # --- Ver detalle ---
  get "/ordenes_compra/:id" do
    @current_page = "ordenes_compra"
    @orden = tenant_db(:ordenes_compra).where(id: params[:id]).first
    halt 404, "Orden de compra no encontrada" unless @orden

    @proveedor = tenant_db(:proveedores).where(id: @orden[:proveedor_id]).first
    @items     = DB[:ordenes_compra_items].where(orden_compra_id: @orden[:id]).order(:id).all
    @page_title = "Orden #{@orden[:numero]}"

    erb :"crm/compras/ordenes_compra/ver"
  end

  # --- Crear ---
  post "/ordenes_compra" do
    proveedor_id = params[:proveedor_id].to_s.strip
    fecha        = params[:fecha].to_s.strip
    notas        = params[:notas].to_s.strip
    items        = parsear_items(params[:items])

    if proveedor_id.empty?
      set_flash(:error, "Elegí un proveedor")
      redirect t("/ordenes_compra/nuevo")
    end

    if items.empty?
      set_flash(:error, "Agregá al menos un ítem")
      redirect t("/ordenes_compra/nuevo")
    end

    numero = siguiente_numero
    total  = calcular_total(items)

    orden_id = nil
    DB.transaction do
      orden_id = DB[:ordenes_compra].insert(
        tenant_id:    current_tenant_id,
        numero:       numero,
        proveedor_id: proveedor_id.to_i,
        fecha:        fecha.empty? ? Date.today : fecha,
        total:        total,
        estado:       "borrador",
        notas:        notas.empty? ? nil : notas
      )

      items.each do |it|
        DB[:ordenes_compra_items].insert(
          orden_compra_id: orden_id,
          articulo_id:     it[:articulo_id],
          descripcion:     it[:descripcion],
          cantidad:        it[:cantidad],
          precio:          it[:precio],
          total:           it[:total]
        )
      end
    end

    set_flash(:success, "Orden #{numero} creada")
    redirect t("/ordenes_compra/#{orden_id}")
  end

  # --- Form edición (solo borrador) ---
  get "/ordenes_compra/:id/editar" do
    @current_page = "ordenes_compra"
    @orden = tenant_db(:ordenes_compra).where(id: params[:id]).first
    halt 404, "Orden de compra no encontrada" unless @orden

    if @orden[:estado] != "borrador"
      set_flash(:error, "Solo se pueden editar órdenes en borrador")
      redirect t("/ordenes_compra/#{@orden[:id]}")
    end

    @page_title = "Editar orden #{@orden[:numero]}"
    @items = DB[:ordenes_compra_items].where(orden_compra_id: @orden[:id]).order(:id).all
    cargar_opciones_form
    erb :"crm/compras/ordenes_compra/editar"
  end

  # --- Actualizar (solo borrador) ---
  post "/ordenes_compra/:id" do
    orden = tenant_db(:ordenes_compra).where(id: params[:id]).first
    halt 404, "Orden de compra no encontrada" unless orden

    if orden[:estado] != "borrador"
      set_flash(:error, "Solo se pueden editar órdenes en borrador")
      redirect t("/ordenes_compra/#{orden[:id]}")
    end

    proveedor_id = params[:proveedor_id].to_s.strip
    fecha        = params[:fecha].to_s.strip
    notas        = params[:notas].to_s.strip
    items        = parsear_items(params[:items])

    if proveedor_id.empty? || items.empty?
      set_flash(:error, "Proveedor e ítems son obligatorios")
      redirect t("/ordenes_compra/#{orden[:id]}/editar")
    end

    total = calcular_total(items)

    DB.transaction do
      DB[:ordenes_compra].where(id: orden[:id]).update(
        proveedor_id: proveedor_id.to_i,
        fecha:        fecha.empty? ? orden[:fecha] : fecha,
        total:        total,
        notas:        notas.empty? ? nil : notas,
        updated_at:   Sequel::CURRENT_TIMESTAMP
      )

      DB[:ordenes_compra_items].where(orden_compra_id: orden[:id]).delete
      items.each do |it|
        DB[:ordenes_compra_items].insert(
          orden_compra_id: orden[:id],
          articulo_id:     it[:articulo_id],
          descripcion:     it[:descripcion],
          cantidad:        it[:cantidad],
          precio:          it[:precio],
          total:           it[:total]
        )
      end
    end

    set_flash(:success, "Orden #{orden[:numero]} actualizada")
    redirect t("/ordenes_compra/#{orden[:id]}")
  end

  # --- Cambiar estado ---
  post "/ordenes_compra/:id/estado" do
    orden = tenant_db(:ordenes_compra).where(id: params[:id]).first
    halt 404, "Orden de compra no encontrada" unless orden

    nuevo = params[:estado].to_s
    halt 400, "Estado inválido" unless ESTADOS.include?(nuevo)

    DB[:ordenes_compra].where(id: orden[:id]).update(
      estado:     nuevo,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    # Al recibir la orden, entra la mercadería al stock
    generar_movimientos_orden(tenant_db(:ordenes_compra).where(id: orden[:id]).first) if nuevo == "recibida"

    set_flash(:success, "Orden #{orden[:numero]} marcada como #{nuevo}")
    redirect t("/ordenes_compra/#{orden[:id]}")
  end

  # --- Anular ---
  post "/ordenes_compra/:id/eliminar" do
    orden = tenant_db(:ordenes_compra).where(id: params[:id]).first
    halt 404, "Orden de compra no encontrada" unless orden

    if orden[:estado] == "recibida"
      set_flash(:error, "No se puede anular una orden ya recibida")
      redirect t("/ordenes_compra/#{orden[:id]}")
    end

    DB[:ordenes_compra].where(id: orden[:id]).update(
      estado:     "anulada",
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Orden #{orden[:numero]} anulada")
    redirect t("/ordenes_compra")
  end

  # ============================================================
  # Helpers
  # ============================================================
  helpers do
    def cargar_opciones_form
      @proveedores = tenant_db(:proveedores).where(activo: true).order(:nombre).all
      @articulos   = tenant_db(:articulos).where(activo: true).order(:nombre).all
    end

    def siguiente_numero
      ultimo = tenant_db(:ordenes_compra).order(Sequel.desc(:id)).get(:numero)
      n = ultimo.to_s[/\d+/].to_i + 1
      "OC-#{n.to_s.rjust(6, '0')}"
    end

    def parsear_items(raw)
      return [] if raw.nil?
      lista = raw.is_a?(Hash) ? raw.values : raw
      lista.map do |it|
        desc = it[:descripcion].to_s.strip
        cant = it[:cantidad].to_f
        prec = it[:precio].to_f
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

    def calcular_total(items)
      items.sum { |i| i[:total] }.round(2)
    end
  end
end
