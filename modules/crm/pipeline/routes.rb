class PipelineRoutes < BaseApp
  # ============================================================
  # PIPELINE DE OPORTUNIDADES
  # ============================================================

  before do
    if request.path_info.start_with?("/pipeline")
      require_login
      halt 403, "Sin permiso para acceder al Pipeline" unless puede?(:pipeline)
    end
  end

  # --- Kanban ---
  get "/pipeline" do
    @current_page = "pipeline"
    @page_title   = "Pipeline de ventas"

    @etapas = tenant_db(:pipeline_etapas)
      .where(activo: true)
      .order(:orden)
      .all

    # Oportunidades activas, agrupadas por etapa
    @oportunidades_por_etapa = {}

    tenant_db(:oportunidades)
      .where(estado: "abierta")
      .order(Sequel.desc(:updated_at))
      .all
      .each do |op|
        @oportunidades_por_etapa[op[:etapa_id]] ||= []
        @oportunidades_por_etapa[op[:etapa_id]] << op
      end

    erb :"crm/pipeline/index"
  end

  # --- Form alta ---
  get "/pipeline/nuevo" do
    @current_page = "pipeline"
    @page_title   = "Nueva oportunidad"
    @oportunidad  = nil
    @etapas       = tenant_db(:pipeline_etapas).where(activo: true).order(:orden).all
    @clientes     = tenant_db(:clientes).where(activo: true).order(:nombre).all
    @leads        = tenant_db(:leads).where(activo: true).order(:nombre).all
    @usuarios     = tenant_db(:usuarios).where(activo: true).order(:nombre).all

    erb :"crm/pipeline/nuevo"
  end

  # --- Crear ---
  post "/pipeline" do
    titulo      = params[:titulo].to_s.strip
    cliente_id  = params[:cliente_id].to_s.strip
    lead_id     = params[:lead_id].to_s.strip
    etapa_id    = params[:etapa_id].to_s.strip
    monto       = params[:monto_estimado].to_s.strip
    fecha       = params[:fecha_cierre_estimada].to_s.strip
    responsable = params[:responsable_id].to_s.strip
    notas       = params[:notas].to_s.strip

    if titulo.empty?
      set_flash(:error, "El título es obligatorio")
      redirect t("/pipeline/nuevo")
    end

    if cliente_id.empty? && lead_id.empty?
      set_flash(:error, "Elegí un cliente o un lead")
      redirect t("/pipeline/nuevo")
    end

    # Etapa por defecto si no eligió
    if etapa_id.empty?
      etapa_id = tenant_db(:pipeline_etapas).where(activo: true).order(:orden).get(:id)
    end

    DB[:oportunidades].insert(
      tenant_id:             current_tenant_id,
      titulo:                titulo,
      cliente_id:            cliente_id.empty? ? nil : cliente_id.to_i,
      lead_id:               lead_id.empty? ? nil : lead_id.to_i,
      etapa_id:              etapa_id.to_i,
      monto_estimado:        monto.empty? ? nil : monto.to_f,
      fecha_cierre_estimada: fecha.empty? ? nil : fecha,
      responsable_id:        responsable.empty? ? current_user[:id] : responsable.to_i,
      notas:                 notas.empty? ? nil : notas,
      estado:                "abierta"
    )

    set_flash(:success, "Oportunidad '#{titulo}' creada")
    redirect t("/pipeline")
  end

  # --- Form edición ---
  get "/pipeline/:id/editar" do
    @current_page = "pipeline"
    @oportunidad  = tenant_db(:oportunidades).where(id: params[:id]).first

    halt 404, "Oportunidad no encontrada" unless @oportunidad

    @page_title = "Editar oportunidad"
    @etapas     = tenant_db(:pipeline_etapas).where(activo: true).order(:orden).all
    @clientes   = tenant_db(:clientes).where(activo: true).order(:nombre).all
    @leads      = tenant_db(:leads).where(activo: true).order(:nombre).all
    @usuarios   = tenant_db(:usuarios).where(activo: true).order(:nombre).all

    erb :"crm/pipeline/editar"
  end

  # --- Actualizar ---
  post "/pipeline/:id" do
    oportunidad = tenant_db(:oportunidades).where(id: params[:id]).first
    halt 404, "Oportunidad no encontrada" unless oportunidad

    titulo      = params[:titulo].to_s.strip
    cliente_id  = params[:cliente_id].to_s.strip
    lead_id     = params[:lead_id].to_s.strip
    monto       = params[:monto_estimado].to_s.strip
    fecha       = params[:fecha_cierre_estimada].to_s.strip
    responsable = params[:responsable_id].to_s.strip
    notas       = params[:notas].to_s.strip

    if titulo.empty?
      set_flash(:error, "El título es obligatorio")
      redirect t("/pipeline/#{oportunidad[:id]}/editar")
    end

    DB[:oportunidades].where(id: oportunidad[:id]).update(
      titulo:                titulo,
      cliente_id:            cliente_id.empty? ? nil : cliente_id.to_i,
      lead_id:               lead_id.empty? ? nil : lead_id.to_i,
      monto_estimado:        monto.empty? ? nil : monto.to_f,
      fecha_cierre_estimada: fecha.empty? ? nil : fecha,
      responsable_id:        responsable.empty? ? oportunidad[:responsable_id] : responsable.to_i,
      notas:                 notas.empty? ? nil : notas,
      updated_at:            Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Oportunidad actualizada")
    redirect t("/pipeline")
  end

  # --- Mover de etapa (drag & drop) ---
  post "/pipeline/:id/mover" do
    oportunidad = tenant_db(:oportunidades).where(id: params[:id]).first
    halt 404, "Oportunidad no encontrada" unless oportunidad

    nueva_etapa_id = params[:etapa_id].to_i
    etapa = tenant_db(:pipeline_etapas).where(id: nueva_etapa_id).first
    halt 404, "Etapa no encontrada" unless etapa

    etapa_anterior_id = oportunidad[:etapa_id]

    # No hacer nada si es la misma etapa
    if etapa_anterior_id == nueva_etapa_id
      return { ok: true }.to_json
    end

    DB.transaction do
      # Actualizar etapa
      DB[:oportunidades].where(id: oportunidad[:id]).update(
        etapa_id:   nueva_etapa_id,
        updated_at: Sequel::CURRENT_TIMESTAMP
      )

      # Registrar en historial
      DB[:oportunidades_historial].insert(
        tenant_id:         current_tenant_id,
        oportunidad_id:    oportunidad[:id],
        etapa_anterior_id: etapa_anterior_id,
        etapa_nueva_id:    nueva_etapa_id,
        usuario_id:        current_user[:id]
      )
    end

    content_type :json
    { ok: true }.to_json
  end

  # --- Eliminar (soft) ---
  post "/pipeline/:id/eliminar" do
    oportunidad = tenant_db(:oportunidades).where(id: params[:id]).first
    halt 404, "Oportunidad no encontrada" unless oportunidad

    DB[:oportunidades].where(id: oportunidad[:id]).update(
      estado:     "perdida",
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Oportunidad '#{oportunidad[:titulo]}' marcada como perdida")
    redirect t("/pipeline")
  end
end