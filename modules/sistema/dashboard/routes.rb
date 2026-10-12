# modules/dashboard/routes.rb

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

    # ---- Métricas generales ----
    @total_clientes   = tenant_db(:clientes).where(activo: true).count
    @total_leads      = tenant_db(:leads).where(activo: true).count

    # Oportunidades abiertas y su monto
    ops_abiertas = tenant_db(:oportunidades).where(estado: "abierta").all
    @ops_abiertas_count = ops_abiertas.size
    @ops_abiertas_monto = ops_abiertas.sum { |o| o[:monto_estimado].to_f }

    # Ganadas este mes
    inicio_mes = Date.new(Date.today.year, Date.today.month, 1)
    ganadas_mes = tenant_db(:oportunidades)
      .where(estado: "ganada")
      .where { fecha_cierre_real >= inicio_mes }
      .all
    @ganadas_mes_count = ganadas_mes.size
    @ganadas_mes_monto = ganadas_mes.sum { |o| o[:monto_estimado].to_f }

    # ---- Leads por estado ----
    @leads_por_estado = tenant_db(:leads)
      .where(activo: true)
      .group_and_count(:estado)
      .to_hash(:estado, :count)

    # ---- Pipeline snapshot ----
    etapas = tenant_db(:pipeline_etapas).where(activo: true).order(:orden).all
    @pipeline_snapshot = etapas.map do |etapa|
      ops = tenant_db(:oportunidades)
        .where(etapa_id: etapa[:id], estado: "abierta")
        .all
      {
        etapa:      etapa,
        count:      ops.size,
        monto:      ops.sum { |o| o[:monto_estimado].to_f }
      }
    end

    # ---- Últimas oportunidades ----
    @ultimas_ops = tenant_db(:oportunidades)
      .where(estado: "abierta")
      .order(Sequel.desc(:updated_at))
      .limit(5)
      .all

    # ---- Últimos leads ----
    @ultimos_leads = tenant_db(:leads)
      .where(activo: true)
      .order(Sequel.desc(:created_at))
      .limit(5)
      .all

    erb :"sistema/dashboard/index"
  end
end