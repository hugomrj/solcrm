class ContactosRoutes < BaseApp
  # ============================================================
  # GESTIÓN DE CONTACTOS
  # ============================================================

  before do
    if request.path_info.start_with?("/contactos")
      require_login
      halt 403, "Sin permiso para acceder a Contactos" unless puede?(:contactos)
    end
  end

  # --- Listado ---
  get "/contactos" do
    @current_page = "contactos"
    @page_title   = "Contactos"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:contactos)

    # Filtro por cliente
    if params[:cliente_id] && !params[:cliente_id].to_s.empty?
      dataset = dataset.where(cliente_id: params[:cliente_id].to_i)
    end

    # Filtro por estado
    case params[:estado]
    when "activos"   then dataset = dataset.where(activo: true)
    when "inactivos" then dataset = dataset.where(activo: false)
    end

    # Búsqueda
    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:nombre,   patron) |
        Sequel.ilike(:cargo,    patron) |
        Sequel.ilike(:email,    patron) |
        Sequel.ilike(:telefono, patron)
      )
    end

    @contactos = dataset.order(:nombre).paginate(page, 25)
    @clientes  = tenant_db(:clientes).where(activo: true).order(:nombre).all
    @filtros   = {
      q:          q,
      cliente_id: params[:cliente_id],
      estado:     params[:estado]
    }

    erb :"crm/contactos/index"
  end

  # --- Form alta ---
  get "/contactos/nuevo" do
    @current_page = "contactos"
    @page_title   = "Nuevo contacto"
    @contacto     = nil
    @clientes     = tenant_db(:clientes).where(activo: true).order(:nombre).all

    # Pre-seleccionar cliente si viene por query string
    @cliente_preseleccionado = params[:cliente_id]

    erb :"crm/contactos/nuevo"
  end

  # --- Crear ---
  post "/contactos" do
    cliente_id = params[:cliente_id].to_s.strip
    nombre     = params[:nombre].to_s.strip
    cargo      = params[:cargo].to_s.strip
    email      = params[:email].to_s.strip
    telefono   = params[:telefono].to_s.strip
    notas      = params[:notas].to_s.strip

    if cliente_id.empty? || nombre.empty?
      set_flash(:error, "Cliente y nombre son obligatorios")
      redirect t("/contactos/nuevo")
    end

    # Validar que el cliente pertenezca al tenant
    cliente = tenant_db(:clientes).where(id: cliente_id.to_i).first
    if cliente.nil?
      set_flash(:error, "Cliente no encontrado")
      redirect t("/contactos/nuevo")
    end

    DB[:contactos].insert(
      tenant_id:  current_tenant_id,
      cliente_id: cliente_id.to_i,
      nombre:     nombre,
      cargo:      cargo.empty? ? nil : cargo,
      email:      email.empty? ? nil : email,
      telefono:   telefono.empty? ? nil : telefono,
      notas:      notas.empty? ? nil : notas,
      activo:     true
    )

    set_flash(:success, "Contacto '#{nombre}' creado")
    redirect t("/contactos")
  end

  # --- Form edición ---
  get "/contactos/:id/editar" do
    @current_page = "contactos"
    @contacto = tenant_db(:contactos).where(id: params[:id]).first

    halt 404, "Contacto no encontrado" unless @contacto

    @page_title = "Editar contacto"
    @clientes   = tenant_db(:clientes).where(activo: true).order(:nombre).all

    erb :"crm/contactos/editar"
  end

  # --- Actualizar ---
  post "/contactos/:id" do
    contacto = tenant_db(:contactos).where(id: params[:id]).first
    halt 404, "Contacto no encontrado" unless contacto

    cliente_id = params[:cliente_id].to_s.strip
    nombre     = params[:nombre].to_s.strip
    cargo      = params[:cargo].to_s.strip
    email      = params[:email].to_s.strip
    telefono   = params[:telefono].to_s.strip
    notas      = params[:notas].to_s.strip

    if cliente_id.empty? || nombre.empty?
      set_flash(:error, "Cliente y nombre son obligatorios")
      redirect t("/contactos/#{contacto[:id]}/editar")
    end

    cliente = tenant_db(:clientes).where(id: cliente_id.to_i).first
    if cliente.nil?
      set_flash(:error, "Cliente no encontrado")
      redirect t("/contactos/#{contacto[:id]}/editar")
    end

    DB[:contactos].where(id: contacto[:id]).update(
      cliente_id: cliente_id.to_i,
      nombre:     nombre,
      cargo:      cargo.empty? ? nil : cargo,
      email:      email.empty? ? nil : email,
      telefono:   telefono.empty? ? nil : telefono,
      notas:      notas.empty? ? nil : notas,
      activo:     params[:activo] == "1",
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Contacto actualizado")
    redirect t("/contactos")
  end

  # --- Soft delete ---
  post "/contactos/:id/eliminar" do
    contacto = tenant_db(:contactos).where(id: params[:id]).first
    halt 404, "Contacto no encontrado" unless contacto

    DB[:contactos].where(id: contacto[:id]).update(
      activo:     false,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Contacto '#{contacto[:nombre]}' eliminado")
    redirect t("/contactos")
  end
end