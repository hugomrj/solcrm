# modules/crm/inventario/stock/routes.rb

class StockRoutes < BaseApp
  TIPOS = %w[entrada salida].freeze

  before do
    if request.path_info.start_with?("/stock")
      require_login
      halt 403, "Sin permiso para acceder a Stock" unless puede?(:stock)
    end
  end

  # --- Stock actual por artículo ---
  get "/stock" do
    @current_page = "stock"
    @page_title   = "Stock"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:articulos)

    case params[:estado]
    when "activos"   then dataset = dataset.where(activo: true)
    when "inactivos" then dataset = dataset.where(activo: false)
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:nombre, patron) |
        Sequel.ilike(:codigo, patron)
      )
    end

    @articulos = dataset.order(:nombre).paginate(page, ITEMS_POR_PAGINA)
    @stock     = stock_por_articulo(@articulos.map { |a| a[:id] })
    @filtros   = { q: q, estado: params[:estado] }

    erb :"crm/inventario/stock/index"
  end

  # --- Historial de movimientos ---
  get "/stock/movimientos" do
    @current_page = "stock"
    @page_title   = "Movimientos de stock"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:stock_movimientos)

    if InventarioHelpers::TIPOS_MOVIMIENTO.include?(params[:tipo])
      dataset = dataset.where(tipo: params[:tipo])
    end

    if params[:articulo_id] && !params[:articulo_id].to_s.empty?
      dataset = dataset.where(articulo_id: params[:articulo_id].to_i)
    end

    @movimientos = dataset.order(Sequel.desc(:created_at), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
    @articulos_por_id = cargar_por_id(:articulos, @movimientos.map { |m| m[:articulo_id] })
    @articulos = tenant_db(:articulos).order(:nombre).all
    @filtros   = { tipo: params[:tipo], articulo_id: params[:articulo_id] }

    erb :"crm/inventario/stock/movimientos"
  end

  # --- Form movimiento (ruta estática primero) ---
  get "/stock/movimientos/nuevo" do
    @current_page = "stock"
    @page_title   = "Nuevo movimiento"
    @articulo_id  = params[:articulo_id]
    @articulos    = tenant_db(:articulos).where(activo: true).order(:nombre).all
    @stock        = stock_por_articulo(@articulos.map { |a| a[:id] })

    erb :"crm/inventario/stock/nuevo_movimiento"
  end

  # --- Registrar movimiento ---
  post "/stock/movimientos" do
    articulo = tenant_db(:articulos).where(id: params[:articulo_id].to_i).first
    unless articulo
      set_flash(:error, "Elegí un artículo")
      redirect t("/stock/movimientos/nuevo")
    end

    tipo = params[:tipo].to_s
    unless TIPOS.include?(tipo)
      set_flash(:error, "Tipo de movimiento inválido")
      redirect t("/stock/movimientos/nuevo")
    end

    cantidad = params[:cantidad].to_s.tr(",", ".").to_f
    if cantidad <= 0
      set_flash(:error, "La cantidad debe ser mayor a cero")
      redirect t("/stock/movimientos/nuevo?articulo_id=#{articulo[:id]}")
    end

    if tipo == "salida" && cantidad > stock_articulo(articulo[:id])
      set_flash(:error, "No hay stock suficiente (disponible: #{numero_input(stock_articulo(articulo[:id]))})")
      redirect t("/stock/movimientos/nuevo?articulo_id=#{articulo[:id]}")
    end

    registrar_movimiento(
      articulo_id: articulo[:id],
      tipo:        tipo,
      cantidad:    cantidad,
      referencia:  params[:referencia],
      motivo:      params[:motivo]
    )

    set_flash(:success, "#{tipo.capitalize} de #{numero_input(cantidad)} registrada para #{articulo[:nombre]}")
    redirect t("/stock")
  end
end
