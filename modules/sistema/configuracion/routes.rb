# modules/sistema/configuracion/routes.rb

class ConfiguracionRoutes < BaseApp
  PLANES = %w[basico pro enterprise].freeze

  before do
    if request.path_info.start_with?("/configuracion")
      require_login
      halt 403, "Sin permiso para acceder a Configuración" unless puede?(:configuracion)
    end
  end

  get "/configuracion" do
    @current_page = "configuracion"
    @page_title   = "Configuración"
    @empresa = DB[:tenants].where(id: current_tenant_id).first
    halt 404, "Empresa no encontrada" unless @empresa

    erb :"sistema/configuracion/index"
  end

  post "/configuracion" do
    empresa = DB[:tenants].where(id: current_tenant_id).first
    halt 404, "Empresa no encontrada" unless empresa

    nombre = params[:nombre].to_s.strip
    plan   = params[:plan].to_s

    if nombre.empty?
      set_flash(:error, "El nombre de la empresa es obligatorio")
      redirect t("/configuracion")
    end

    plan = empresa[:plan] unless PLANES.include?(plan)

    DB[:tenants].where(id: empresa[:id]).update(
      nombre:     nombre,
      plan:       plan,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Configuración guardada")
    redirect t("/configuracion")
  end
end
