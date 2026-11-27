# modules/operaciones/proyectos/routes.rb
#
# La tabla `proyectos` no tiene `activo`: el "borrado" es estado = cancelado.

class ProyectosRoutes < BaseApp
  ESTADOS = %w[activo pausado completado cancelado].freeze

  before do
    if request.path_info.start_with?("/proyectos")
      require_login
      halt 403, "Sin permiso para acceder a Proyectos" unless puede?(:proyectos)
    end
  end

  # --- Listado ---
  get "/proyectos" do
    @current_page = "proyectos"
    @page_title   = "Proyectos"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:proyectos)

    if ESTADOS.include?(params[:estado])
      dataset = dataset.where(estado: params[:estado])
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:nombre, patron) |
        Sequel.ilike(:notas,  patron)
      )
    end

    @proyectos = dataset.order(Sequel.desc(:created_at), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
    @clientes_por_id = cargar_por_id(:clientes, @proyectos.map { |p| p[:cliente_id] })
    @filtros = { q: q, estado: params[:estado] }

    erb :"operaciones/proyectos/index"
  end

  # --- Form alta ---
  get "/proyectos/nuevo" do
    @current_page = "proyectos"
    @page_title   = "Nuevo proyecto"
    @proyecto     = nil
    cargar_opciones_form
    erb :"operaciones/proyectos/nuevo"
  end

  # --- Crear ---
  post "/proyectos" do
    nombre     = params[:nombre].to_s.strip
    cliente_id = params[:cliente_id].to_s.strip
    estado     = params[:estado].to_s
    inicio     = params[:fecha_inicio].to_s.strip
    fin        = params[:fecha_fin].to_s.strip
    presupuesto = params[:presupuesto].to_s.tr(",", ".").to_f
    notas      = params[:notas].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/proyectos/nuevo")
    end

    estado = "activo" unless ESTADOS.include?(estado)

    DB[:proyectos].insert(
      tenant_id:    current_tenant_id,
      nombre:       nombre,
      cliente_id:   cliente_id.empty? ? nil : cliente_id.to_i,
      estado:       estado,
      fecha_inicio: inicio.empty? ? nil : inicio,
      fecha_fin:    fin.empty? ? nil : fin,
      presupuesto:  presupuesto > 0 ? presupuesto.round(2) : nil,
      notas:        notas.empty? ? nil : notas
    )

    set_flash(:success, "Proyecto '#{nombre}' creado")
    redirect t("/proyectos")
  end

  # --- Form edición ---
  get "/proyectos/:id/editar" do
    @current_page = "proyectos"
    @proyecto = tenant_db(:proyectos).where(id: params[:id]).first
    halt 404, "Proyecto no encontrado" unless @proyecto

    @page_title = "Editar proyecto"
    cargar_opciones_form
    erb :"operaciones/proyectos/editar"
  end

  # --- Actualizar ---
  post "/proyectos/:id" do
    proyecto = tenant_db(:proyectos).where(id: params[:id]).first
    halt 404, "Proyecto no encontrado" unless proyecto

    nombre     = params[:nombre].to_s.strip
    cliente_id = params[:cliente_id].to_s.strip
    estado     = params[:estado].to_s
    inicio     = params[:fecha_inicio].to_s.strip
    fin        = params[:fecha_fin].to_s.strip
    presupuesto = params[:presupuesto].to_s.tr(",", ".").to_f
    notas      = params[:notas].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/proyectos/#{proyecto[:id]}/editar")
    end

    estado = proyecto[:estado] unless ESTADOS.include?(estado)

    DB[:proyectos].where(id: proyecto[:id]).update(
      nombre:       nombre,
      cliente_id:   cliente_id.empty? ? nil : cliente_id.to_i,
      estado:       estado,
      fecha_inicio: inicio.empty? ? nil : inicio,
      fecha_fin:    fin.empty? ? nil : fin,
      presupuesto:  presupuesto > 0 ? presupuesto.round(2) : nil,
      notas:        notas.empty? ? nil : notas,
      updated_at:   Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Proyecto actualizado")
    redirect t("/proyectos")
  end

  # --- Cancelar (no hay soft delete en la tabla) ---
  post "/proyectos/:id/eliminar" do
    proyecto = tenant_db(:proyectos).where(id: params[:id]).first
    halt 404, "Proyecto no encontrado" unless proyecto

    DB[:proyectos].where(id: proyecto[:id]).update(
      estado:     "cancelado",
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Proyecto '#{proyecto[:nombre]}' cancelado")
    redirect t("/proyectos")
  end

  helpers do
    def cargar_opciones_form
      @clientes = tenant_db(:clientes).where(activo: true).order(:nombre).all
    end
  end
end
