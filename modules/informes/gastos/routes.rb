# modules/informes/gastos/routes.rb

class InformesGastosRoutes < BaseApp
  before do
    if request.path_info.start_with?("/informes_gastos")
      require_login
      halt 403, "Sin permiso para acceder a Informes de gastos" unless puede?(:informes_gastos)
    end
  end

  get "/informes_gastos" do
    @current_page = "informes_gastos"
    @page_title   = "Informe de gastos"
    @desde, @hasta = rango_informe

    gastos = tenant_db(:gastos).where(fecha: @desde..@hasta).all

    @cantidad = gastos.size
    @total    = gastos.sum { |g| g[:monto].to_f }
    @promedio = @cantidad > 0 ? @total / @cantidad : 0.0

    # Por categoría
    por_categoria = Hash.new(0.0)
    gastos.each { |g| por_categoria[g[:categoria].to_s.empty? ? "Sin categoría" : g[:categoria]] += g[:monto].to_f }

    @categorias = por_categoria.sort_by { |_c, monto| -monto }.map do |categoria, monto|
      { categoria: categoria, monto: monto, pct: porcentaje(monto, @total) }
    end

    # Serie mensual
    por_mes = Hash.new(0.0)
    gastos.each { |g| por_mes[g[:fecha].strftime("%Y-%m")] += g[:monto].to_f }

    @por_mes = meses_del_rango(@desde, @hasta).map do |clave|
      { etiqueta: etiqueta_mes(clave), monto: por_mes[clave] }
    end
    @max_mes = @por_mes.map { |m| m[:monto] }.max.to_f
    @max_mes = 1.0 if @max_mes <= 0

    # Últimos movimientos
    @ultimos = gastos.sort_by { |g| g[:fecha] }.reverse.first(10)

    erb :"informes/gastos/index"
  end
end
