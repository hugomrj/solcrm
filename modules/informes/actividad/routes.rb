# modules/informes/actividad/routes.rb

class InformesActividadRoutes < BaseApp
  before do
    if request.path_info.start_with?("/informes_actividad")
      require_login
      halt 403, "Sin permiso para acceder a Informes de actividad" unless puede?(:informes_actividad)
    end
  end

  get "/informes_actividad" do
    @current_page = "informes_actividad"
    @page_title   = "Informe de actividad"
    @desde, @hasta = rango_informe

    desde_ts = @desde.to_time
    hasta_ts = (@hasta + 1).to_time

    actividades = tenant_db(:actividades).where(Sequel[:fecha] >= desde_ts).where(Sequel[:fecha] < hasta_ts).all

    @total       = actividades.size
    @completadas = actividades.count { |a| a[:completada] }
    @pendientes  = @total - @completadas
    @cumplimiento = porcentaje(@completadas, @total)

    # Por tipo
    por_tipo = actividades.group_by { |a| a[:tipo] }
    @por_tipo = por_tipo.map do |tipo, lista|
      completadas = lista.count { |a| a[:completada] }
      { tipo: tipo, total: lista.size, completadas: completadas,
        pct: porcentaje(completadas, lista.size) }
    end.sort_by { |t| -t[:total] }

    # Por usuario
    por_usuario = actividades.group_by { |a| a[:usuario_id] }
    @usuarios_por_id = cargar_por_id(:usuarios, por_usuario.keys)
    @por_usuario = por_usuario.map do |usuario_id, lista|
      usuario = @usuarios_por_id[usuario_id]
      { nombre: usuario ? usuario[:nombre] : "Sin asignar",
        total: lista.size,
        completadas: lista.count { |a| a[:completada] } }
    end.sort_by { |u| -u[:total] }

    # Serie mensual
    por_mes = Hash.new { |h, k| h[k] = { total: 0, completadas: 0 } }
    actividades.each do |a|
      clave = a[:fecha] ? a[:fecha].strftime("%Y-%m") : nil
      next unless clave
      por_mes[clave][:total] += 1
      por_mes[clave][:completadas] += 1 if a[:completada]
    end
    @por_mes = meses_del_rango(@desde, @hasta).map do |clave|
      { etiqueta: etiqueta_mes(clave), total: por_mes[clave][:total], completadas: por_mes[clave][:completadas] }
    end

    erb :"informes/actividad/index"
  end
end
