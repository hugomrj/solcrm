# modules/operaciones/soporte/routes.rb

class SoporteRoutes < BaseApp
  ESTADOS     = %w[abierto en_progreso resuelto cerrado].freeze
  PRIORIDADES = %w[baja normal alta urgente].freeze

  before do
    if request.path_info.start_with?("/soporte")
      require_login
      halt 403, "Sin permiso para acceder a Soporte" unless puede?(:soporte)
    end
  end

  # --- Listado ---
  get "/soporte" do
    @current_page = "soporte"
    @page_title   = "Tickets de soporte"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:tickets)

    if ESTADOS.include?(params[:estado])
      dataset = dataset.where(estado: params[:estado])
    end

    if PRIORIDADES.include?(params[:prioridad])
      dataset = dataset.where(prioridad: params[:prioridad])
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:numero,      patron) |
        Sequel.ilike(:asunto,      patron) |
        Sequel.ilike(:descripcion, patron)
      )
    end

    @tickets = dataset.order(Sequel.desc(:created_at), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)

    ids = @tickets.map { |t| t[:id] }
    @mensajes_count = if ids.empty?
      {}
    else
      DB[:tickets_mensajes]
        .where(ticket_id: ids)
        .select(:ticket_id, Sequel.function(:count, :id).as(:total))
        .group(:ticket_id)
        .all
        .each_with_object({}) { |row, hash| hash[row[:ticket_id]] = row[:total] }
    end
    @clientes_por_id = cargar_por_id(:clientes, @tickets.map { |t| t[:cliente_id] })
    @filtros = { q: q, estado: params[:estado], prioridad: params[:prioridad] }

    erb :"operaciones/soporte/index"
  end

  # --- Form alta ---
  get "/soporte/nuevo" do
    @current_page = "soporte"
    @page_title   = "Nuevo ticket"
    @ticket       = nil
    @clientes     = tenant_db(:clientes).where(activo: true).order(:nombre).all
    erb :"operaciones/soporte/nuevo"
  end

  # --- Crear ---
  post "/soporte" do
    cliente_id  = params[:cliente_id].to_s.strip
    asunto      = params[:asunto].to_s.strip
    descripcion = params[:descripcion].to_s.strip
    prioridad   = params[:prioridad].to_s

    if asunto.empty?
      set_flash(:error, "El asunto es obligatorio")
      redirect t("/soporte/nuevo")
    end

    prioridad = "normal" unless PRIORIDADES.include?(prioridad)
    numero = siguiente_numero

    ticket_id = DB[:tickets].insert(
      tenant_id:   current_tenant_id,
      numero:      numero,
      cliente_id:  cliente_id.empty? ? nil : cliente_id.to_i,
      asunto:      asunto,
      descripcion: descripcion.empty? ? nil : descripcion,
      estado:      "abierto",
      prioridad:   prioridad,
      asignado_id: current_user ? current_user[:id] : nil
    )

    set_flash(:success, "Ticket #{numero} creado")
    redirect t("/soporte/#{ticket_id}")
  end

  # --- Ver detalle ---
  get "/soporte/:id" do
    @current_page = "soporte"
    @ticket = tenant_db(:tickets).where(id: params[:id]).first
    halt 404, "Ticket no encontrado" unless @ticket

    @cliente = @ticket[:cliente_id] ? tenant_db(:clientes).where(id: @ticket[:cliente_id]).first : nil
    @mensajes = DB[:tickets_mensajes].where(ticket_id: @ticket[:id]).order(:created_at, :id).all
    @usuarios_por_id = cargar_por_id(:usuarios, @mensajes.map { |m| m[:usuario_id] })
    @asignado = @ticket[:asignado_id] ? tenant_db(:usuarios).where(id: @ticket[:asignado_id]).first : nil
    @page_title = "Ticket #{@ticket[:numero]}"

    erb :"operaciones/soporte/ver"
  end

  # --- Agregar mensaje ---
  post "/soporte/:id/mensaje" do
    ticket = tenant_db(:tickets).where(id: params[:id]).first
    halt 404, "Ticket no encontrado" unless ticket

    mensaje = params[:mensaje].to_s.strip
    if mensaje.empty?
      set_flash(:error, "Escribí un mensaje")
      redirect t("/soporte/#{ticket[:id]}")
    end

    DB[:tickets_mensajes].insert(
      ticket_id:  ticket[:id],
      usuario_id: current_user ? current_user[:id] : nil,
      mensaje:    mensaje
    )

    # Si estaba resuelto/cerrado y el cliente vuelve a escribir, se reabre
    if %w[resuelto cerrado].include?(ticket[:estado])
      DB[:tickets].where(id: ticket[:id]).update(
        estado:     "abierto",
        updated_at: Sequel::CURRENT_TIMESTAMP
      )
    end

    set_flash(:success, "Mensaje agregado")
    redirect t("/soporte/#{ticket[:id]}")
  end

  # --- Cambiar estado ---
  post "/soporte/:id/estado" do
    ticket = tenant_db(:tickets).where(id: params[:id]).first
    halt 404, "Ticket no encontrado" unless ticket

    nuevo = params[:estado].to_s
    halt 400, "Estado inválido" unless ESTADOS.include?(nuevo)

    DB[:tickets].where(id: ticket[:id]).update(
      estado:     nuevo,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Ticket #{ticket[:numero]} marcado como #{nuevo.tr('_', ' ')}")
    redirect t("/soporte/#{ticket[:id]}")
  end

  helpers do
    def siguiente_numero
      ultimo = tenant_db(:tickets).order(Sequel.desc(:id)).get(:numero)
      n = ultimo.to_s[/\d+/].to_i + 1
      "TKT-#{n.to_s.rjust(6, '0')}"
    end
  end
end
