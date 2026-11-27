# modules/operaciones/gastos/routes.rb
#
# Nota: la tabla `gastos` no tiene `activo` ni `updated_at`, así que no hay
# borrado (soft delete imposible). Se permite editar para corregir errores.

class GastosRoutes < BaseApp
  CATEGORIAS_SUGERIDAS = %w[operativo servicios impuestos sueldos marketing otros].freeze

  before do
    if request.path_info.start_with?("/gastos")
      require_login
      halt 403, "Sin permiso para acceder a Gastos" unless puede?(:gastos)
    end
  end

  # --- Listado ---
  get "/gastos" do
    @current_page = "gastos"
    @page_title   = "Gastos"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:gastos)

    unless params[:categoria].to_s.empty?
      dataset = dataset.where(categoria: params[:categoria])
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:concepto, patron) |
        Sequel.ilike(:notas,    patron)
      )
    end

    @gastos = dataset.order(Sequel.desc(:fecha), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
    @total  = dataset.sum(:monto).to_f
    @categorias = tenant_db(:gastos).exclude(categoria: nil).distinct.select_map(:categoria).sort
    @filtros = { q: q, categoria: params[:categoria] }

    erb :"operaciones/gastos/index"
  end

  # --- Form alta ---
  get "/gastos/nuevo" do
    @current_page = "gastos"
    @page_title   = "Nuevo gasto"
    @gasto        = nil
    @categorias_sugeridas = CATEGORIAS_SUGERIDAS
    erb :"operaciones/gastos/nuevo"
  end

  # --- Crear ---
  post "/gastos" do
    concepto = params[:concepto].to_s.strip
    monto    = params[:monto].to_s.tr(",", ".").to_f
    fecha    = params[:fecha].to_s.strip
    categoria = params[:categoria].to_s.strip
    notas    = params[:notas].to_s.strip

    if concepto.empty?
      set_flash(:error, "El concepto es obligatorio")
      redirect t("/gastos/nuevo")
    end

    if monto <= 0
      set_flash(:error, "El monto debe ser mayor a cero")
      redirect t("/gastos/nuevo")
    end

    DB[:gastos].insert(
      tenant_id: current_tenant_id,
      fecha:     fecha.empty? ? Date.today : fecha,
      concepto:  concepto,
      monto:     monto.round(2),
      categoria: categoria.empty? ? nil : categoria,
      notas:     notas.empty? ? nil : notas
    )

    set_flash(:success, "Gasto '#{concepto}' registrado")
    redirect t("/gastos")
  end

  # --- Form edición ---
  get "/gastos/:id/editar" do
    @current_page = "gastos"
    @gasto = tenant_db(:gastos).where(id: params[:id]).first
    halt 404, "Gasto no encontrado" unless @gasto

    @page_title = "Editar gasto"
    @categorias_sugeridas = CATEGORIAS_SUGERIDAS
    erb :"operaciones/gastos/editar"
  end

  # --- Actualizar ---
  post "/gastos/:id" do
    gasto = tenant_db(:gastos).where(id: params[:id]).first
    halt 404, "Gasto no encontrado" unless gasto

    concepto = params[:concepto].to_s.strip
    monto    = params[:monto].to_s.tr(",", ".").to_f
    fecha    = params[:fecha].to_s.strip
    categoria = params[:categoria].to_s.strip
    notas    = params[:notas].to_s.strip

    if concepto.empty? || monto <= 0
      set_flash(:error, "Concepto y monto son obligatorios")
      redirect t("/gastos/#{gasto[:id]}/editar")
    end

    DB[:gastos].where(id: gasto[:id]).update(
      fecha:     fecha.empty? ? gasto[:fecha] : fecha,
      concepto:  concepto,
      monto:     monto.round(2),
      categoria: categoria.empty? ? nil : categoria,
      notas:     notas.empty? ? nil : notas
    )

    set_flash(:success, "Gasto actualizado")
    redirect t("/gastos")
  end
end
