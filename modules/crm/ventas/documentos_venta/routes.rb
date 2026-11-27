# modules/crm/ventas/documentos_venta/routes.rb
#
# Propuestas y presupuestos comparten tabla (`documentos_venta.tipo`) y ciclo de
# vida, así que este módulo define las mismas rutas para ambos con distinto prefijo.

class DocumentosVentaRoutes < BaseApp
  ESTADOS = %w[borrador enviada aceptada rechazada].freeze

  TIPOS = {
    "/propuestas" => {
      tipo: "propuesta", prefijo: "PRO", permiso: :propuestas,
      titulo: "Propuestas", singular: "propuesta", articulo: "la"
    },
    "/presupuestos" => {
      tipo: "presupuesto", prefijo: "PPTO", permiso: :presupuestos,
      titulo: "Presupuestos", singular: "presupuesto", articulo: "el"
    }
  }.freeze

  def self.config_para(path)
    TIPOS.each do |base, cfg|
      return cfg.merge(base: base) if path == base || path.start_with?("#{base}/")
    end
    nil
  end

  before do
    cfg = self.class.config_para(request.path_info)
    if cfg
      require_login
      halt 403, "Sin permiso para acceder a #{cfg[:titulo]}" unless puede?(cfg[:permiso])
    end
  end

  TIPOS.each do |base, cfg|
    tipo    = cfg[:tipo]
    prefijo = cfg[:prefijo]
    page_key = base.delete("/")

    # --- Listado ---
    get "#{base}" do
      @cfg          = cfg
      @base         = base
      @current_page = page_key
      @page_title   = cfg[:titulo]

      page = (params[:page] || 1).to_i
      page = 1 if page < 1

      dataset = tenant_db(:documentos_venta).where(tipo: tipo)

      if ESTADOS.include?(params[:estado])
        dataset = dataset.where(estado: params[:estado])
      end

      q = params[:q].to_s.strip
      unless q.empty?
        patron = "%#{q}%"
        dataset = dataset.where(
          Sequel.ilike(:numero, patron) |
          Sequel.ilike(:notas,  patron)
        )
      end

      @documentos = dataset.order(Sequel.desc(:fecha), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
      @clientes_por_id = cargar_por_id(:clientes, @documentos.map { |d| d[:cliente_id] })
      @filtros = { q: q, estado: params[:estado] }

      erb :"crm/ventas/documentos_venta/index"
    end

    # --- Form alta (antes de /:id) ---
    get "#{base}/nuevo" do
      @cfg          = cfg
      @base         = base
      @current_page = page_key
      @page_title   = "Nueva #{cfg[:singular]}"
      @documento    = nil
      @items        = []
      cargar_opciones_form
      erb :"crm/ventas/documentos_venta/nuevo"
    end

    # --- Crear ---
    post "#{base}" do
      cliente_id = params[:cliente_id].to_s.strip
      fecha      = params[:fecha].to_s.strip
      validez    = params[:validez].to_s.strip
      notas      = params[:notas].to_s.strip
      items      = parsear_items(params[:items])

      if cliente_id.empty?
        set_flash(:error, "Elegí un cliente")
        redirect t("#{base}/nuevo")
      end

      if items.empty?
        set_flash(:error, "Agregá al menos un ítem")
        redirect t("#{base}/nuevo")
      end

      subtotal, impuestos, total = calcular_totales(items)
      numero = siguiente_numero(tipo, prefijo)

      documento_id = nil
      DB.transaction do
        documento_id = DB[:documentos_venta].insert(
          tenant_id:  current_tenant_id,
          tipo:       tipo,
          numero:     numero,
          cliente_id: cliente_id.to_i,
          fecha:      fecha.empty? ? Date.today : fecha,
          validez:    validez.empty? ? nil : validez,
          subtotal:   subtotal,
          impuestos:  impuestos,
          total:      total,
          estado:     "borrador",
          notas:      notas.empty? ? nil : notas
        )

        items.each do |it|
          DB[:documentos_venta_items].insert(
            documento_venta_id: documento_id,
            articulo_id:        it[:articulo_id],
            descripcion:        it[:descripcion],
            cantidad:           it[:cantidad],
            precio:             it[:precio],
            total:              it[:total]
          )
        end
      end

      set_flash(:success, "#{cfg[:titulo].chomp('s')} #{numero} creada")
      redirect t("#{base}/#{documento_id}")
    end

    # --- Form edición (solo borrador) ---
    get "#{base}/:id/editar" do
      @cfg          = cfg
      @base         = base
      @current_page = page_key
      @documento = tenant_db(:documentos_venta).where(id: params[:id], tipo: tipo).first
      halt 404, "Documento no encontrado" unless @documento

      if @documento[:estado] != "borrador"
        set_flash(:error, "Solo se puede editar en borrador")
        redirect t("#{base}/#{@documento[:id]}")
      end

      @page_title = "Editar #{cfg[:singular]} #{@documento[:numero]}"
      @items = DB[:documentos_venta_items].where(documento_venta_id: @documento[:id]).order(:id).all
      cargar_opciones_form
      erb :"crm/ventas/documentos_venta/editar"
    end

    # --- Actualizar (solo borrador) ---
    post "#{base}/:id" do
      documento = tenant_db(:documentos_venta).where(id: params[:id], tipo: tipo).first
      halt 404, "Documento no encontrado" unless documento

      if documento[:estado] != "borrador"
        set_flash(:error, "Solo se puede editar en borrador")
        redirect t("#{base}/#{documento[:id]}")
      end

      cliente_id = params[:cliente_id].to_s.strip
      fecha      = params[:fecha].to_s.strip
      validez    = params[:validez].to_s.strip
      notas      = params[:notas].to_s.strip
      items      = parsear_items(params[:items])

      if cliente_id.empty? || items.empty?
        set_flash(:error, "Cliente e ítems son obligatorios")
        redirect t("#{base}/#{documento[:id]}/editar")
      end

      subtotal, impuestos, total = calcular_totales(items)

      DB.transaction do
        DB[:documentos_venta].where(id: documento[:id]).update(
          cliente_id: cliente_id.to_i,
          fecha:      fecha.empty? ? documento[:fecha] : fecha,
          validez:    validez.empty? ? nil : validez,
          subtotal:   subtotal,
          impuestos:  impuestos,
          total:      total,
          notas:      notas.empty? ? nil : notas,
          updated_at: Sequel::CURRENT_TIMESTAMP
        )

        DB[:documentos_venta_items].where(documento_venta_id: documento[:id]).delete
        items.each do |it|
          DB[:documentos_venta_items].insert(
            documento_venta_id: documento[:id],
            articulo_id:        it[:articulo_id],
            descripcion:        it[:descripcion],
            cantidad:           it[:cantidad],
            precio:             it[:precio],
            total:              it[:total]
          )
        end
      end

      set_flash(:success, "#{cfg[:titulo].chomp('s')} #{documento[:numero]} actualizada")
      redirect t("#{base}/#{documento[:id]}")
    end

    # --- Cambiar estado ---
    post "#{base}/:id/estado" do
      documento = tenant_db(:documentos_venta).where(id: params[:id], tipo: tipo).first
      halt 404, "Documento no encontrado" unless documento

      nuevo = params[:estado].to_s
      halt 400, "Estado inválido" unless ESTADOS.include?(nuevo)

      DB[:documentos_venta].where(id: documento[:id]).update(
        estado:     nuevo,
        updated_at: Sequel::CURRENT_TIMESTAMP
      )

      set_flash(:success, "#{documento[:numero]} marcado como #{nuevo}")
      redirect t("#{base}/#{documento[:id]}")
    end

    # --- Convertir en factura ---
    post "#{base}/:id/convertir" do
      documento = tenant_db(:documentos_venta).where(id: params[:id], tipo: tipo).first
      halt 404, "Documento no encontrado" unless documento

      if documento[:factura_id]
        set_flash(:error, "Este documento ya fue convertido en factura")
        redirect t("#{base}/#{documento[:id]}")
      end

      items = DB[:documentos_venta_items].where(documento_venta_id: documento[:id]).order(:id).all
      if items.empty?
        set_flash(:error, "No se puede convertir un documento sin ítems")
        redirect t("#{base}/#{documento[:id]}")
      end

      factura_id = nil
      DB.transaction do
        factura_id = DB[:facturas].insert(
          tenant_id:  current_tenant_id,
          numero:     siguiente_numero_factura,
          cliente_id: documento[:cliente_id],
          fecha:      Date.today,
          subtotal:   documento[:subtotal],
          impuestos:  documento[:impuestos],
          total:      documento[:total],
          estado:     "borrador",
          notas:      "Generada desde #{cfg[:singular]} #{documento[:numero]}"
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

        DB[:documentos_venta].where(id: documento[:id]).update(
          estado:     "aceptada",
          factura_id: factura_id,
          updated_at: Sequel::CURRENT_TIMESTAMP
        )
      end

      set_flash(:success, "Convertida en factura. Revisala y emitila para cobrarla.")
      redirect t("/ventas/facturas/#{factura_id}")
    end

    # --- Ver detalle ---
    get "#{base}/:id" do
      @cfg          = cfg
      @base         = base
      @current_page = page_key
      @documento = tenant_db(:documentos_venta).where(id: params[:id], tipo: tipo).first
      halt 404, "Documento no encontrado" unless @documento

      @cliente = @documento[:cliente_id] ? tenant_db(:clientes).where(id: @documento[:cliente_id]).first : nil
      @items   = DB[:documentos_venta_items].where(documento_venta_id: @documento[:id]).order(:id).all
      @factura = @documento[:factura_id] ? tenant_db(:facturas).where(id: @documento[:factura_id]).first : nil
      @page_title = "#{cfg[:titulo].chomp('s')} #{@documento[:numero]}"

      erb :"crm/ventas/documentos_venta/ver"
    end
  end

  # ============================================================
  # Helpers
  # ============================================================
  helpers do
    def cargar_opciones_form
      @clientes  = tenant_db(:clientes).where(activo: true).order(:nombre).all
      @articulos = tenant_db(:articulos).where(activo: true).order(:nombre).all
    end

    def siguiente_numero(tipo, prefijo)
      ultimo = tenant_db(:documentos_venta).where(tipo: tipo).order(Sequel.desc(:id)).get(:numero)
      n = ultimo.to_s[/\d+/].to_i + 1
      "#{prefijo}-#{n.to_s.rjust(6, '0')}"
    end

    def siguiente_numero_factura
      ultimo = tenant_db(:facturas).order(Sequel.desc(:id)).get(:numero)
      n = ultimo.to_s[/\d+/].to_i + 1
      "FAC-#{n.to_s.rjust(6, '0')}"
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

    def calcular_totales(items)
      subtotal  = items.sum { |i| i[:total] }.round(2)
      impuestos = (subtotal * 0.10).round(2)
      total     = (subtotal + impuestos).round(2)
      [subtotal, impuestos, total]
    end
  end
end
