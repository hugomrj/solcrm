# modules/sistema/dashboard/routes.rb

class DashboardRoutes < BaseApp
  before do
    if request.path_info.start_with?("/dashboard")
      require_login
      halt 403, "Sin permiso" unless puede?(:dashboard)
    end
  end

  get "/dashboard" do
    @current_page = "dashboard"
    @page_title   = "Panel de Control"

    hoy        = Date.today
    inicio_mes = Date.new(hoy.year, hoy.month, 1)
    inicio_6m  = inicio_mes << 5

    # ---------- KPIs del mes ----------
    @facturado_mes = tenant_db(:facturas)
      .where(estado: %w[emitida pagada], fecha: inicio_mes..hoy).sum(:total).to_f
    @cobrado_mes   = tenant_db(:pagos).where(fecha: inicio_mes..hoy).sum(:monto).to_f
    @gastos_mes    = tenant_db(:gastos).where(fecha: inicio_mes..hoy).sum(:monto).to_f
    @resultado_mes = @cobrado_mes - @gastos_mes

    # ---------- Por cobrar (facturas emitidas) ----------
    emitidas = tenant_db(:facturas).where(estado: "emitida").all
    ids      = emitidas.map { |f| f[:id] }
    pagado   = sumar_por_factura(tenant_db(:pagos), ids)
    notas    = sumar_por_factura(tenant_db(:notas_credito), ids)
    @por_cobrar = emitidas.sum do |f|
      f[:total].to_f - pagado[f[:id]].to_f - notas[f[:id]].to_f
    end
    @facturas_por_cobrar = emitidas.size

    # ---------- CRM ----------
    @total_clientes    = tenant_db(:clientes).where(activo: true).count
    @total_leads       = tenant_db(:leads).where(activo: true).count
    ops_abiertas       = tenant_db(:oportunidades).where(estado: "abierta").all
    @ops_abiertas_count = ops_abiertas.size
    @ops_abiertas_monto = ops_abiertas.sum { |o| o[:monto_estimado].to_f }

    ganadas_mes = tenant_db(:oportunidades).where(estado: "ganada").where { fecha_cierre_real >= inicio_mes }.all
    @ganadas_mes_count = ganadas_mes.size
    @ganadas_mes_monto = ganadas_mes.sum { |o| o[:monto_estimado].to_f }

    @tickets_abiertos = tenant_db(:tickets).where(estado: %w[abierto en_progreso]).count

    # ---------- Serie de 6 meses ----------
    facturas_6m = tenant_db(:facturas)
      .where(estado: %w[emitida pagada], fecha: inicio_6m..hoy)
      .select(:fecha, :total, :cliente_id).all
    pagos_6m = tenant_db(:pagos).where(fecha: inicio_6m..hoy).select(:fecha, :monto).all
    gastos_6m = tenant_db(:gastos).where(fecha: inicio_6m..hoy).select(:fecha, :monto, :categoria).all

    facturado_h = Hash.new(0.0)
    facturas_6m.each { |f| facturado_h[f[:fecha].strftime("%Y-%m")] += f[:total].to_f }

    cobrado_h = Hash.new(0.0)
    pagos_6m.each { |p| cobrado_h[p[:fecha].strftime("%Y-%m")] += p[:monto].to_f }

    gastos_h = Hash.new(0.0)
    gastos_6m.each { |g| gastos_h[g[:fecha].strftime("%Y-%m")] += g[:monto].to_f }

    @por_mes = meses_del_rango(inicio_6m, hoy).map do |clave|
      {
        etiqueta:  etiqueta_mes(clave),
        facturado: facturado_h[clave],
        cobrado:   cobrado_h[clave],
        gastos:    gastos_h[clave]
      }
    end
    @max_mes = ([@por_mes.map { |m| m[:facturado] }.max, @por_mes.map { |m| m[:cobrado] }.max].compact.max || 0).to_f
    @max_mes = 1.0 if @max_mes <= 0

    # ---------- Pipeline por etapa ----------
    etapas = tenant_db(:pipeline_etapas).where(activo: true).order(:orden).all
    @pipeline = etapas.map do |etapa|
      en_etapa = ops_abiertas.select { |o| o[:etapa_id] == etapa[:id] }
      { nombre: etapa[:nombre], count: en_etapa.size,
        monto: en_etapa.sum { |o| o[:monto_estimado].to_f } }
    end
    @max_pipeline = (@pipeline.map { |p| p[:monto] }.max || 0).to_f
    @max_pipeline = 1.0 if @max_pipeline <= 0
    @total_pipeline = @pipeline.sum { |p| p[:monto] }

    # ---------- Gastos por categoría (6 meses) ----------
    categorias = Hash.new(0.0)
    gastos_6m.each do |g|
      nombre = g[:categoria].to_s.empty? ? "Sin categoría" : g[:categoria]
      categorias[nombre] += g[:monto].to_f
    end
    total_cat = categorias.values.sum
    paleta = %w[var(--brand) var(--purple) var(--blue) var(--warn) var(--green) var(--cyan) var(--red)]
    @gastos_categorias = categorias.sort_by { |_c, m| -m }.first(6).each_with_index.map do |(cat, monto), i|
      { categoria: cat, monto: monto, pct: total_cat > 0 ? (monto / total_cat * 100).round(1) : 0.0,
        color: paleta[i % paleta.size] }
    end
    @total_gastos_6m = total_cat

    # ---------- Top clientes (6 meses) ----------
    totales = Hash.new(0.0)
    facturas_6m.each { |f| totales[f[:cliente_id]] += f[:total].to_f }
    ids_top = totales.sort_by { |_id, m| -m }.first(5)
    @clientes_por_id = cargar_por_id(:clientes, ids_top.map(&:first))
    @top_clientes = ids_top.map { |id, monto| { cliente: @clientes_por_id[id], monto: monto } }
    @max_cliente = (@top_clientes.map { |t| t[:monto] }.max || 0).to_f
    @max_cliente = 1.0 if @max_cliente <= 0

    # ---------- Listados ----------
    @ultimas_facturas = tenant_db(:facturas).order(Sequel.desc(:fecha), Sequel.desc(:id)).limit(5).all
    @facturas_clientes = cargar_por_id(:clientes, @ultimas_facturas.map { |f| f[:cliente_id] })

    @tickets_recientes = tenant_db(:tickets)
      .where(estado: %w[abierto en_progreso])
      .order(Sequel.desc(:created_at)).limit(5).all

    @proximas_actividades = tenant_db(:actividades)
      .where(completada: false)
      .where { fecha >= Time.now }
      .order(Sequel.asc(:fecha)).limit(5).all

    erb :"sistema/dashboard/index"
  end
end
