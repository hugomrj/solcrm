class ActividadesRoutes < BaseApp
  TIPOS = %w[llamada email reunion nota tarea].freeze

  before do
    if request.path_info.start_with?("/actividades", "/calendario", "/tareas", "/llamadas")
      require_login
    end
  end

  # ============================================================
  # LISTADO GENERAL
  # ============================================================
  get "/actividades" do
    @current_page = "actividades"
    @page_title   = "Actividades"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:actividades)

    if TIPOS.include?(params[:tipo])
      dataset = dataset.where(tipo: params[:tipo])
    end

    case params[:estado]
    when "pendientes"  then dataset = dataset.where(completada: false)
    when "completadas" then dataset = dataset.where(completada: true)
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:titulo, patron) |
        Sequel.ilike(:descripcion, patron)
      )
    end

    @actividades = dataset.order(Sequel.desc(:fecha), Sequel.desc(:created_at)).paginate(page, 25)
    @filtros     = { q: q, tipo: params[:tipo], estado: params[:estado] }

    erb :"crm/actividades/index"
  end

  # ============================================================
  # TAREAS (filtro de tipo=tarea)
  # ============================================================
  get "/tareas" do
    @current_page = "tareas"
    @page_title   = "Tareas"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:actividades).where(tipo: "tarea")

    case params[:estado]
    when "pendientes"  then dataset = dataset.where(completada: false)
    when "completadas" then dataset = dataset.where(completada: true)
    end

    @actividades = dataset.order(Sequel.asc(:completada), Sequel.asc(:fecha)).paginate(page, 25)
    @filtros     = { estado: params[:estado] }

    erb :"crm/actividades/lista_tareas"
  end

  # ============================================================
  # LLAMADAS
  # ============================================================
  get "/llamadas" do
    @current_page = "llamadas"
    @page_title   = "Llamadas"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:actividades).where(tipo: "llamada")
    @actividades = dataset.order(Sequel.desc(:fecha)).paginate(page, 25)
    @filtros = {}

    erb :"crm/actividades/lista_llamadas"
  end

  # ============================================================
  # CALENDARIO
  # ============================================================
  get "/calendario" do
    @current_page = "calendario"
    @page_title   = "Calendario"

    # Mes actual o el que venga por params
    hoy = Date.today
    @year  = (params[:year]  || hoy.year).to_i
    @month = (params[:month] || hoy.month).to_i

    inicio = Date.new(@year, @month, 1)
    fin    = inicio.next_month - 1

    @actividades = tenant_db(:actividades)
      .where { fecha >= inicio }
      .where { fecha <= fin.to_time + 86399 }
      .order(:fecha)
      .all

    # Agrupar por día
    @por_dia = {}
    @actividades.each do |a|
      next unless a[:fecha]
      dia = a[:fecha].to_date
      @por_dia[dia] ||= []
      @por_dia[dia] << a
    end

    erb :"crm/actividades/calendario"
  end

  # ============================================================
  # FORM ALTA
  # ============================================================
  get "/actividades/nuevo" do
    @current_page = "actividades"
    @page_title   = "Nueva actividad"
    @actividad    = nil

    cargar_opciones_form

    # Pre-seleccionar tipo si viene por query string
    @tipo_preseleccionado    = params[:tipo]
    @entidad_preseleccionada = params[:entidad] # "cliente:5" o "lead:3"

    erb :"crm/actividades/nuevo"
  end

  # ============================================================
  # CREAR
  # ============================================================
  post "/actividades" do
    tipo        = params[:tipo].to_s.strip
    titulo      = params[:titulo].to_s.strip
    descripcion = params[:descripcion].to_s.strip
    fecha       = params[:fecha].to_s.strip
    entidad     = params[:entidad].to_s.strip

    if titulo.empty?
      set_flash(:error, "El título es obligatorio")
      redirect t("/actividades/nuevo")
    end

    tipo = "tarea" unless TIPOS.include?(tipo)

    entidad_tipo, entidad_id = parsear_entidad(entidad)

    DB[:actividades].insert(
      tenant_id:    current_tenant_id,
      tipo:         tipo,
      titulo:       titulo,
      descripcion:  descripcion.empty? ? nil : descripcion,
      entidad_tipo: entidad_tipo,
      entidad_id:   entidad_id,
      fecha:        fecha.empty? ? nil : fecha,
      completada:   false,
      usuario_id:   current_user[:id]
    )

    set_flash(:success, "Actividad '#{titulo}' creada")
    redirect t("/actividades")
  end

  # ============================================================
  # FORM EDICIÓN
  # ============================================================
  get "/actividades/:id/editar" do
    @current_page = "actividades"
    @actividad    = tenant_db(:actividades).where(id: params[:id]).first

    halt 404, "Actividad no encontrada" unless @actividad

    @page_title = "Editar actividad"
    cargar_opciones_form

    erb :"crm/actividades/editar"
  end

  # ============================================================
  # ACTUALIZAR
  # ============================================================
  post "/actividades/:id" do
    actividad = tenant_db(:actividades).where(id: params[:id]).first
    halt 404, "Actividad no encontrada" unless actividad

    tipo        = params[:tipo].to_s.strip
    titulo      = params[:titulo].to_s.strip
    descripcion = params[:descripcion].to_s.strip
    fecha       = params[:fecha].to_s.strip
    entidad     = params[:entidad].to_s.strip

    if titulo.empty?
      set_flash(:error, "El título es obligatorio")
      redirect t("/actividades/#{actividad[:id]}/editar")
    end

    tipo = actividad[:tipo] unless TIPOS.include?(tipo)
    entidad_tipo, entidad_id = parsear_entidad(entidad)

    DB[:actividades].where(id: actividad[:id]).update(
      tipo:         tipo,
      titulo:       titulo,
      descripcion:  descripcion.empty? ? nil : descripcion,
      entidad_tipo: entidad_tipo,
      entidad_id:   entidad_id,
      fecha:        fecha.empty? ? nil : fecha,
      updated_at:   Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Actividad actualizada")
    redirect t("/actividades")
  end

  # ============================================================
  # TOGGLE COMPLETADA
  # ============================================================
  post "/actividades/:id/completar" do
    actividad = tenant_db(:actividades).where(id: params[:id]).first
    halt 404, "Actividad no encontrada" unless actividad

    nuevo_estado = !actividad[:completada]

    DB[:actividades].where(id: actividad[:id]).update(
      completada:    nuevo_estado,
      completada_at: nuevo_estado ? Time.now : nil,
      updated_at:    Sequel::CURRENT_TIMESTAMP
    )

    content_type :json
    { ok: true, completada: nuevo_estado }.to_json
  end

  # ============================================================
  # ELIMINAR
  # ============================================================
  post "/actividades/:id/eliminar" do
    actividad = tenant_db(:actividades).where(id: params[:id]).first
    halt 404, "Actividad no encontrada" unless actividad

    DB[:actividades].where(id: actividad[:id]).delete

    set_flash(:success, "Actividad eliminada")
    redirect t("/actividades")
  end

  # ============================================================
  # HELPERS
  # ============================================================
  helpers do
    def cargar_opciones_form
      @clientes      = tenant_db(:clientes).where(activo: true).order(:nombre).all
      @leads         = tenant_db(:leads).where(activo: true).order(:nombre).all
      @oportunidades = tenant_db(:oportunidades).where(estado: "abierta").order(:titulo).all
    end

    # Convierte "cliente:5" → ["cliente", 5]
    def parsear_entidad(entidad)
      return [nil, nil] if entidad.nil? || entidad.empty?
      partes = entidad.split(":")
      return [nil, nil] if partes.size != 2
      [partes[0], partes[1].to_i]
    end
  end
end