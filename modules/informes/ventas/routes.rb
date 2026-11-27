# modules/informes/ventas/routes.rb

class InformesVentasRoutes < BaseApp
  before do
    if request.path_info.start_with?("/informes_ventas")
      require_login
      halt 403, "Sin permiso para acceder a Informes de ventas" unless puede?(:informes_ventas)
    end
  end

  get "/informes_ventas" do
    @current_page = "informes_ventas"
    @page_title   = "Informe de ventas"
    @desde, @hasta = rango_informe

    facturas = tenant_db(:facturas).where(estado: %w[emitida pagada], fecha: @desde..@hasta).all
    pagos    = tenant_db(:pagos).where(fecha: @desde..@hasta).all

    @cantidad_facturas = facturas.size
    @facturado   = facturas.sum { |f| f[:total].to_f }
    @cobrado     = pagos.sum { |p| p[:monto].to_f }
    @acreditado  = tenant_db(:notas_credito).where(fecha: @desde..@hasta).sum(:monto).to_f
    @saldo       = @facturado - @cobrado - @acreditado
    @ticket_promedio = @cantidad_facturas > 0 ? @facturado / @cantidad_facturas : 0.0

    # Serie mensual
    facturado_mes = Hash.new(0.0)
    facturas.each { |f| facturado_mes[f[:fecha].strftime("%Y-%m")] += f[:total].to_f }

    cobrado_mes = Hash.new(0.0)
    pagos.each { |p| cobrado_mes[p[:fecha].strftime("%Y-%m")] += p[:monto].to_f }

    @por_mes = meses_del_rango(@desde, @hasta).map do |clave|
      { clave: clave, etiqueta: etiqueta_mes(clave),
        facturado: facturado_mes[clave], cobrado: cobrado_mes[clave] }
    end
    @max_mes = @por_mes.map { |m| m[:facturado] }.max.to_f
    @max_mes = 1.0 if @max_mes <= 0

    # Top clientes
    totales = Hash.new(0.0)
    facturas.each { |f| totales[f[:cliente_id]] += f[:total].to_f }
    @clientes_por_id = cargar_por_id(:clientes, totales.keys)
    @top_clientes = totales.sort_by { |_id, monto| -monto }.first(5).map do |id, monto|
      { cliente: @clientes_por_id[id], monto: monto }
    end

    erb :"informes/ventas/index"
  end
end
