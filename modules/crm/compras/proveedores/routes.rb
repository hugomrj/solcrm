# modules/crm/compras/proveedores/routes.rb

class ProveedoresRoutes < BaseApp
  before do
    if request.path_info.start_with?("/proveedores")
      require_login
      halt 403, "Sin permiso para acceder a Proveedores" unless puede?(:proveedores)
    end
  end

  # --- Listado ---
  get "/proveedores" do
    @current_page = "proveedores"
    @page_title   = "Proveedores"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:proveedores)

    case params[:estado]
    when "activos"   then dataset = dataset.where(activo: true)
    when "inactivos" then dataset = dataset.where(activo: false)
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:nombre,    patron) |
        Sequel.ilike(:documento, patron) |
        Sequel.ilike(:email,     patron) |
        Sequel.ilike(:telefono,  patron)
      )
    end

    @proveedores = dataset.order(:nombre).paginate(page, ITEMS_POR_PAGINA)
    @filtros     = { q: q, estado: params[:estado] }

    erb :"crm/compras/proveedores/index"
  end

  # --- Form alta ---
  get "/proveedores/nuevo" do
    @current_page = "proveedores"
    @page_title   = "Nuevo proveedor"
    @proveedor    = nil
    erb :"crm/compras/proveedores/nuevo"
  end

  # --- Crear ---
  post "/proveedores" do
    nombre    = params[:nombre].to_s.strip
    documento = params[:documento].to_s.strip
    email     = params[:email].to_s.strip
    telefono  = params[:telefono].to_s.strip
    direccion = params[:direccion].to_s.strip
    notas     = params[:notas].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/proveedores/nuevo")
    end

    unless documento.empty?
      if tenant_db(:proveedores).where(documento: documento).count > 0
        set_flash(:error, "Ya existe un proveedor con ese documento en esta empresa")
        redirect t("/proveedores/nuevo")
      end
    end

    DB[:proveedores].insert(
      tenant_id: current_tenant_id,
      nombre:    nombre,
      documento: documento.empty? ? nil : documento,
      email:     email.empty? ? nil : email,
      telefono:  telefono.empty? ? nil : telefono,
      direccion: direccion.empty? ? nil : direccion,
      notas:     notas.empty? ? nil : notas,
      activo:    true
    )

    set_flash(:success, "Proveedor '#{nombre}' creado")
    redirect t("/proveedores")
  end

  # --- Form edición ---
  get "/proveedores/:id/editar" do
    @current_page = "proveedores"
    @proveedor = tenant_db(:proveedores).where(id: params[:id]).first
    halt 404, "Proveedor no encontrado" unless @proveedor

    @page_title = "Editar proveedor"
    erb :"crm/compras/proveedores/editar"
  end

  # --- Actualizar ---
  post "/proveedores/:id" do
    proveedor = tenant_db(:proveedores).where(id: params[:id]).first
    halt 404, "Proveedor no encontrado" unless proveedor

    nombre    = params[:nombre].to_s.strip
    documento = params[:documento].to_s.strip
    email     = params[:email].to_s.strip
    telefono  = params[:telefono].to_s.strip
    direccion = params[:direccion].to_s.strip
    notas     = params[:notas].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/proveedores/#{proveedor[:id]}/editar")
    end

    unless documento.empty?
      duplicado = tenant_db(:proveedores)
        .where(documento: documento)
        .exclude(id: proveedor[:id])
        .count

      if duplicado > 0
        set_flash(:error, "Ya existe otro proveedor con ese documento")
        redirect t("/proveedores/#{proveedor[:id]}/editar")
      end
    end

    DB[:proveedores].where(id: proveedor[:id]).update(
      nombre:     nombre,
      documento:  documento.empty? ? nil : documento,
      email:      email.empty? ? nil : email,
      telefono:   telefono.empty? ? nil : telefono,
      direccion:  direccion.empty? ? nil : direccion,
      notas:      notas.empty? ? nil : notas,
      activo:     params[:activo] == "1",
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Proveedor actualizado")
    redirect t("/proveedores")
  end

  # --- Soft delete ---
  post "/proveedores/:id/eliminar" do
    proveedor = tenant_db(:proveedores).where(id: params[:id]).first
    halt 404, "Proveedor no encontrado" unless proveedor

    DB[:proveedores].where(id: proveedor[:id]).update(
      activo:     false,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Proveedor '#{proveedor[:nombre]}' eliminado")
    redirect t("/proveedores")
  end
end
