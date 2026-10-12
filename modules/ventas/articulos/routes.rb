class ArticulosRoutes < BaseApp
  TIPOS = %w[producto servicio].freeze

  before do
    if request.path_info.start_with?("/articulos")
      require_login
      halt 403, "Sin permiso para acceder a Artículos" unless puede?(:articulos_venta)
    end
  end

  # --- Listado ---
  get "/articulos" do
    @current_page = "articulos_venta"
    @page_title   = "Artículos"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:articulos)

    if TIPOS.include?(params[:tipo])
      dataset = dataset.where(tipo: params[:tipo])
    end

    case params[:estado]
    when "activos"   then dataset = dataset.where(activo: true)
    when "inactivos" then dataset = dataset.where(activo: false)
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:nombre,      patron) |
        Sequel.ilike(:codigo,      patron) |
        Sequel.ilike(:descripcion, patron)
      )
    end

    @articulos = dataset.order(:nombre).paginate(page, 25)
    @filtros   = { q: q, tipo: params[:tipo], estado: params[:estado] }

    erb :"ventas/articulos/index"
  end

  # --- Form alta ---
  get "/articulos/nuevo" do
    @current_page = "articulos_venta"
    @page_title   = "Nuevo artículo"
    @articulo     = nil
    erb :"ventas/articulos/nuevo"
  end

  # --- Crear ---
  post "/articulos" do
    codigo      = params[:codigo].to_s.strip
    nombre      = params[:nombre].to_s.strip
    descripcion = params[:descripcion].to_s.strip
    precio      = params[:precio].to_s.strip
    tipo        = params[:tipo].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/articulos/nuevo")
    end

    if !codigo.empty? && tenant_db(:articulos).where(codigo: codigo).count > 0
      set_flash(:error, "Ya existe un artículo con ese código")
      redirect t("/articulos/nuevo")
    end

    tipo = "producto" unless TIPOS.include?(tipo)

    DB[:articulos].insert(
      tenant_id:   current_tenant_id,
      codigo:      codigo.empty? ? nil : codigo,
      nombre:      nombre,
      descripcion: descripcion.empty? ? nil : descripcion,
      precio:      precio.empty? ? 0 : precio.to_f,
      tipo:        tipo,
      activo:      true
    )

    set_flash(:success, "Artículo '#{nombre}' creado")
    redirect t("/articulos")
  end

  # --- Form edición ---
  get "/articulos/:id/editar" do
    @current_page = "articulos_venta"
    @articulo = tenant_db(:articulos).where(id: params[:id]).first

    halt 404, "Artículo no encontrado" unless @articulo

    @page_title = "Editar artículo"
    erb :"ventas/articulos/editar"
  end

  # --- Actualizar ---
  post "/articulos/:id" do
    articulo = tenant_db(:articulos).where(id: params[:id]).first
    halt 404, "Artículo no encontrado" unless articulo

    codigo      = params[:codigo].to_s.strip
    nombre      = params[:nombre].to_s.strip
    descripcion = params[:descripcion].to_s.strip
    precio      = params[:precio].to_s.strip
    tipo        = params[:tipo].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/articulos/#{articulo[:id]}/editar")
    end

    if !codigo.empty?
      duplicado = tenant_db(:articulos)
        .where(codigo: codigo)
        .exclude(id: articulo[:id])
        .count

      if duplicado > 0
        set_flash(:error, "Ya existe otro artículo con ese código")
        redirect t("/articulos/#{articulo[:id]}/editar")
      end
    end

    tipo = articulo[:tipo] unless TIPOS.include?(tipo)

    DB[:articulos].where(id: articulo[:id]).update(
      codigo:      codigo.empty? ? nil : codigo,
      nombre:      nombre,
      descripcion: descripcion.empty? ? nil : descripcion,
      precio:      precio.empty? ? 0 : precio.to_f,
      tipo:        tipo,
      activo:      params[:activo] == "1",
      updated_at:  Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Artículo actualizado")
    redirect t("/articulos")
  end

  # --- Soft delete ---
  post "/articulos/:id/eliminar" do
    articulo = tenant_db(:articulos).where(id: params[:id]).first
    halt 404, "Artículo no encontrado" unless articulo

    DB[:articulos].where(id: articulo[:id]).update(
      activo:     false,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Artículo '#{articulo[:nombre]}' eliminado")
    redirect t("/articulos")
  end
end