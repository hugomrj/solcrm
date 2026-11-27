# modules/crm/inventario/ajustes/routes.rb

class AjustesInventarioRoutes < BaseApp
  before do
    if request.path_info.start_with?("/ajustes_inventario")
      require_login
      halt 403, "Sin permiso para acceder a Ajustes de inventario" unless puede?(:ajustes_inventario)
    end
  end

  # --- Form de ajuste + últimos ajustes ---
  get "/ajustes_inventario" do
    @current_page = "ajustes_inventario"
    @page_title   = "Ajustes de inventario"

    @articulos = tenant_db(:articulos).where(activo: true).order(:nombre).all
    @stock     = stock_por_articulo(@articulos.map { |a| a[:id] })

    @ajustes = tenant_db(:stock_movimientos)
      .where(tipo: "ajuste")
      .order(Sequel.desc(:created_at), Sequel.desc(:id))
      .limit(20)
      .all

    @articulos_por_id = cargar_por_id(:articulos, @ajustes.map { |m| m[:articulo_id] })

    erb :"crm/inventario/ajustes/index"
  end

  # --- Aplicar ajuste ---
  post "/ajustes_inventario" do
    articulo = tenant_db(:articulos).where(id: params[:articulo_id].to_i).first
    unless articulo
      set_flash(:error, "Elegí un artículo")
      redirect t("/ajustes_inventario")
    end

    stock_real = params[:stock_real].to_s.tr(",", ".").to_f
    if stock_real < 0
      set_flash(:error, "El stock contado no puede ser negativo")
      redirect t("/ajustes_inventario")
    end

    actual = stock_articulo(articulo[:id])
    delta  = (stock_real - actual).round(2)

    if delta.abs < 0.009
      set_flash(:error, "El stock contado coincide con el del sistema (#{numero_input(actual)}). No hay nada que ajustar.")
      redirect t("/ajustes_inventario")
    end

    registrar_movimiento(
      articulo_id: articulo[:id],
      tipo:        "ajuste",
      cantidad:    delta,
      referencia:  "Ajuste de inventario",
      motivo:      params[:motivo]
    )

    set_flash(:success, "Ajuste aplicado a #{articulo[:nombre]}: #{numero_input(actual)} → #{numero_input(stock_real)}")
    redirect t("/stock")
  end
end
