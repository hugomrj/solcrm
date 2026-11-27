# modules/operaciones/suscripciones/routes.rb

class SuscripcionesRoutes < BaseApp
  ESTADOS        = %w[activa pausada cancelada].freeze
  PERIODICIDADES = %w[mensual trimestral anual].freeze

  before do
    if request.path_info.start_with?("/suscripciones")
      require_login
      halt 403, "Sin permiso para acceder a Suscripciones" unless puede?(:suscripciones)
    end
  end

  # --- Listado ---
  get "/suscripciones" do
    @current_page = "suscripciones"
    @page_title   = "Suscripciones"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:suscripciones)

    if ESTADOS.include?(params[:estado])
      dataset = dataset.where(estado: params[:estado])
    end

    if params[:cliente_id] && !params[:cliente_id].to_s.empty?
      dataset = dataset.where(cliente_id: params[:cliente_id].to_i)
    end

    @suscripciones = dataset.order(Sequel.desc(:fecha_inicio), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
    @clientes_por_id = cargar_por_id(:clientes, @suscripciones.map { |s| s[:cliente_id] })
    @clientes = tenant_db(:clientes).where(activo: true).order(:nombre).all
    @filtros  = { estado: params[:estado], cliente_id: params[:cliente_id] }

    # Ingreso mensual normalizado (MRR aproximado)
    @mrr = tenant_db(:suscripciones).where(estado: "activa").all.sum do |s|
      monto = s[:monto].to_f
      case s[:periodicidad]
      when "anual"      then monto / 12.0
      when "trimestral" then monto / 3.0
      else monto
      end
    end

    erb :"operaciones/suscripciones/index"
  end

  # --- Form alta ---
  get "/suscripciones/nuevo" do
    @current_page = "suscripciones"
    @page_title   = "Nueva suscripción"
    @suscripcion  = nil
    cargar_opciones_form
    erb :"operaciones/suscripciones/nuevo"
  end

  # --- Crear ---
  post "/suscripciones" do
    datos = datos_form

    if datos[:cliente_id].nil?
      set_flash(:error, "Elegí un cliente")
      redirect t("/suscripciones/nuevo")
    end

    if datos[:plan].empty?
      set_flash(:error, "El plan es obligatorio")
      redirect t("/suscripciones/nuevo")
    end

    if datos[:monto] <= 0
      set_flash(:error, "El monto debe ser mayor a cero")
      redirect t("/suscripciones/nuevo")
    end

    DB[:suscripciones].insert(
      tenant_id:    current_tenant_id,
      cliente_id:   datos[:cliente_id],
      plan:         datos[:plan],
      monto:        datos[:monto],
      periodicidad: datos[:periodicidad],
      fecha_inicio: datos[:fecha_inicio],
      fecha_fin:    datos[:fecha_fin],
      estado:       datos[:estado]
    )

    set_flash(:success, "Suscripción a '#{datos[:plan]}' creada")
    redirect t("/suscripciones")
  end

  # --- Form edición ---
  get "/suscripciones/:id/editar" do
    @current_page = "suscripciones"
    @suscripcion = tenant_db(:suscripciones).where(id: params[:id]).first
    halt 404, "Suscripción no encontrada" unless @suscripcion

    @page_title = "Editar suscripción"
    cargar_opciones_form
    erb :"operaciones/suscripciones/editar"
  end

  # --- Actualizar ---
  post "/suscripciones/:id" do
    suscripcion = tenant_db(:suscripciones).where(id: params[:id]).first
    halt 404, "Suscripción no encontrada" unless suscripcion

    datos = datos_form

    if datos[:cliente_id].nil? || datos[:plan].empty? || datos[:monto] <= 0
      set_flash(:error, "Cliente, plan y monto son obligatorios")
      redirect t("/suscripciones/#{suscripcion[:id]}/editar")
    end

    DB[:suscripciones].where(id: suscripcion[:id]).update(
      cliente_id:   datos[:cliente_id],
      plan:         datos[:plan],
      monto:        datos[:monto],
      periodicidad: datos[:periodicidad],
      fecha_inicio: datos[:fecha_inicio],
      fecha_fin:    datos[:fecha_fin],
      estado:       datos[:estado],
      updated_at:   Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Suscripción actualizada")
    redirect t("/suscripciones")
  end

  # --- Cancelar (no hay soft delete en la tabla) ---
  post "/suscripciones/:id/eliminar" do
    suscripcion = tenant_db(:suscripciones).where(id: params[:id]).first
    halt 404, "Suscripción no encontrada" unless suscripcion

    DB[:suscripciones].where(id: suscripcion[:id]).update(
      estado:     "cancelada",
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Suscripción cancelada")
    redirect t("/suscripciones")
  end

  helpers do
    def cargar_opciones_form
      @clientes = tenant_db(:clientes).where(activo: true).order(:nombre).all
    end

    def datos_form
      cliente_id = params[:cliente_id].to_s.strip
      estado     = params[:estado].to_s
      periodicidad = params[:periodicidad].to_s
      inicio     = params[:fecha_inicio].to_s.strip
      fin        = params[:fecha_fin].to_s.strip

      {
        cliente_id:   cliente_id.empty? ? nil : cliente_id.to_i,
        plan:         params[:plan].to_s.strip,
        monto:        params[:monto].to_s.tr(",", ".").to_f.round(2),
        periodicidad: PERIODICIDADES.include?(periodicidad) ? periodicidad : "mensual",
        fecha_inicio: inicio.empty? ? Date.today : inicio,
        fecha_fin:    fin.empty? ? nil : fin,
        estado:       ESTADOS.include?(estado) ? estado : "activa"
      }
    end
  end
end
