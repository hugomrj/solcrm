# modules/informes/pipeline/routes.rb

class InformesPipelineRoutes < BaseApp
  before do
    if request.path_info.start_with?("/informes_pipeline")
      require_login
      halt 403, "Sin permiso para acceder a Informes de pipeline" unless puede?(:informes_pipeline)
    end
  end

  get "/informes_pipeline" do
    @current_page = "informes_pipeline"
    @page_title   = "Informe de conversión"

    etapas = tenant_db(:pipeline_etapas).order(:orden).all
    ops    = tenant_db(:oportunidades).all

    @abiertas = ops.select { |o| o[:estado] == "abierta" }
    @ganadas  = ops.select { |o| o[:estado] == "ganada" }
    @perdidas = ops.select { |o| o[:estado] == "perdida" }

    @monto_abierto = @abiertas.sum { |o| o[:monto_estimado].to_f }
    @monto_ganado  = @ganadas.sum  { |o| o[:monto_estimado].to_f }

    cerradas = @ganadas.size + @perdidas.size
    @tasa_conversion = porcentaje(@ganadas.size, cerradas)
    @ticket_promedio = @ganadas.size > 0 ? @monto_ganado / @ganadas.size : 0.0

    # Distribución por etapa (solo oportunidades abiertas)
    @por_etapa = etapas.map do |etapa|
      en_etapa = @abiertas.select { |o| o[:etapa_id] == etapa[:id] }
      {
        nombre:     etapa[:nombre],
        cantidad:   en_etapa.size,
        monto:      en_etapa.sum { |o| o[:monto_estimado].to_f },
        probabilidad: etapa[:probabilidad].to_i
      }
    end

    @max_etapa = @por_etapa.map { |e| e[:monto] }.max.to_f
    @max_etapa = 1.0 if @max_etapa <= 0

    # Sin etapa asignada
    sin_etapa = @abiertas.reject { |o| etapas.any? { |e| e[:id] == o[:etapa_id] } }
    @sin_etapa = { cantidad: sin_etapa.size, monto: sin_etapa.sum { |o| o[:monto_estimado].to_f } }

    erb :"informes/pipeline/index"
  end
end
