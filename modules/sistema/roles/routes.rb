# modules/sistema/roles/routes.rb
#
# OJO: `roles`, `permisos` y `roles_permisos` son tablas GLOBALES (sin tenant_id).
# Editar permisos de un rol afecta a todos los tenants que lo usan.

class RolesRoutes < BaseApp
  # Agrupación de permisos para la UI (solo presentación)
  GRUPOS = {
    "CRM"           => %w[dashboard pipeline clientes contactos leads calendario tareas llamadas],
    "Ventas"        => %w[propuestas presupuestos facturas pagos notas_credito articulos_venta],
    "Compras"       => %w[proveedores ordenes_compra contratos_compra],
    "Inventario"    => %w[productos stock ajustes_inventario],
    "Operaciones"   => %w[proyectos soporte suscripciones gastos],
    "Archivos"      => %w[explorador compartir],
    "Informes"      => %w[informes_ventas informes_gastos informes_pipeline informes_actividad],
    "Sistema"       => %w[usuarios roles configuracion]
  }.freeze

  before do
    if request.path_info.start_with?("/roles")
      require_login
      halt 403, "Sin permiso para acceder a Roles" unless puede?(:roles)
    end
  end

  # --- Listado ---
  get "/roles" do
    @current_page = "roles"
    @page_title   = "Roles y permisos"

    @roles = DB[:roles].order(:nombre).all

    @permisos_por_rol  = contar_por(DB[:roles_permisos], :rol_id)
    @usuarios_por_rol  = contar_por(DB[:usuarios_roles].where(tenant_id: current_tenant_id), :rol_id)
    @total_permisos    = DB[:permisos].count

    erb :"sistema/roles/index"
  end

  # --- Form alta (estática antes que /:id) ---
  get "/roles/nuevo" do
    @current_page = "roles"
    @page_title   = "Nuevo rol"
    erb :"sistema/roles/nuevo"
  end

  # --- Crear rol ---
  post "/roles" do
    nombre      = params[:nombre].to_s.strip.downcase
    descripcion = params[:descripcion].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre del rol es obligatorio")
      redirect t("/roles/nuevo")
    end

    if DB[:roles].where(nombre: nombre).count > 0
      set_flash(:error, "Ya existe un rol con ese nombre")
      redirect t("/roles/nuevo")
    end

    rol_id = DB[:roles].insert(nombre: nombre, descripcion: descripcion.empty? ? nil : descripcion)
    set_flash(:success, "Rol '#{nombre}' creado. Ahora asignale permisos.")
    redirect t("/roles/#{rol_id}")
  end

  # --- Editor de permisos ---
  get "/roles/:id" do
    @current_page = "roles"
    @rol = DB[:roles].where(id: params[:id]).first
    halt 404, "Rol no encontrado" unless @rol

    @permisos = DB[:permisos].order(:modulo).all
    @asignados = DB[:roles_permisos].where(rol_id: @rol[:id]).select_map(:permiso_id)
    @asignados = @asignados.to_a.each_with_object({}) { |id, h| h[id] = true }

    @usuarios_asignados = DB[:usuarios_roles]
      .join(:usuarios, id: :usuario_id)
      .where(Sequel[:usuarios_roles][:rol_id] => @rol[:id])
      .where(Sequel[:usuarios_roles][:tenant_id] => current_tenant_id)
      .select_map(Sequel[:usuarios][:nombre])

    @page_title = "Permisos de #{@rol[:nombre]}"
    erb :"sistema/roles/permisos"
  end

  # --- Guardar permisos ---
  post "/roles/:id" do
    rol = DB[:roles].where(id: params[:id]).first
    halt 404, "Rol no encontrado" unless rol

    ids = Array(params[:permisos]).map(&:to_i).uniq

    DB.transaction do
      DB[:roles_permisos].where(rol_id: rol[:id]).delete
      ids.each do |permiso_id|
        DB[:roles_permisos].insert(rol_id: rol[:id], permiso_id: permiso_id)
      end
    end

    set_flash(:success, "Permisos de '#{rol[:nombre]}' actualizados (#{ids.size})")
    redirect t("/roles")
  end

  helpers do
    def contar_por(dataset, columna)
      dataset
        .select(columna, Sequel.function(:count, :id).as(:total))
        .group(columna)
        .all
        .each_with_object({}) { |row, hash| hash[row[columna]] = row[:total] }
    end
  end
end
