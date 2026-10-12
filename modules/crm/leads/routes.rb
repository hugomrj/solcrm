class LeadsRoutes < BaseApp
    ESTADOS = %w[nuevo contactado calificado convertido descartado].freeze
    ORIGENES = %w[web referido llamada whatsapp otro].freeze
  
    # ============================================================
    # GESTIÓN DE LEADS (cualquier usuario logueado)
    # ============================================================
  
    before do
      if request.path_info.start_with?("/leads")
        require_login
        halt 403, "Sin permiso para acceder a Clientes potenciales" unless puede?(:leads)
      end
    end
  
    # --- Listado ---
    get "/leads" do
      @current_page = "leads"
      @page_title   = "Clientes potenciales"
  
      page = (params[:page] || 1).to_i
      page = 1 if page < 1
  
      dataset = tenant_db(:leads)
  
      # Filtro por estado
      if ESTADOS.include?(params[:estado])
        dataset = dataset.where(estado: params[:estado])
      end
  
      # Filtro por origen
      if ORIGENES.include?(params[:origen])
        dataset = dataset.where(origen: params[:origen])
      end
  
      # Filtro por activos/inactivos
      case params[:activo]
      when "activos"   then dataset = dataset.where(activo: true)
      when "inactivos" then dataset = dataset.where(activo: false)
      end
  
      # Búsqueda
      q = params[:q].to_s.strip
      unless q.empty?
        patron = "%#{q}%"
        dataset = dataset.where(
          Sequel.ilike(:nombre,   patron) |
          Sequel.ilike(:empresa,  patron) |
          Sequel.ilike(:email,    patron) |
          Sequel.ilike(:telefono, patron)
        )
      end
  
      @leads   = dataset.order(Sequel.desc(:created_at)).paginate(page, 25)
      @filtros = {
        q:       q,
        estado:  params[:estado],
        origen:  params[:origen],
        activo:  params[:activo]
      }
  
      erb :"crm/leads/index"
    end
  
    # --- Form alta ---
    get "/leads/nuevo" do
      @current_page = "leads"
      @page_title   = "Nuevo cliente potencial"
      @lead         = nil
      @usuarios     = tenant_db(:usuarios).where(activo: true).order(:nombre).all
      erb :"crm/leads/nuevo"
    end
  
    # --- Crear ---
    post "/leads" do
      nombre    = params[:nombre].to_s.strip
      empresa   = params[:empresa].to_s.strip
      email     = params[:email].to_s.strip
      telefono  = params[:telefono].to_s.strip
      origen    = params[:origen].to_s.strip
      estado    = params[:estado].to_s.strip
      notas     = params[:notas].to_s.strip
  
      if nombre.empty?
        set_flash(:error, "El nombre es obligatorio")
        redirect t("/leads/nuevo")
      end
  
      estado = "nuevo" unless ESTADOS.include?(estado)
      origen = nil if origen.empty?
  
      DB[:leads].insert(
        tenant_id:      current_tenant_id,
        nombre:         nombre,
        empresa:        empresa.empty? ? nil : empresa,
        email:          email.empty? ? nil : email,
        telefono:       telefono.empty? ? nil : telefono,
        origen:         origen,
        estado:         estado,
        notas:          notas.empty? ? nil : notas,
        responsable_id: params[:responsable_id].to_s.empty? ? current_user[:id] : params[:responsable_id].to_i,
        activo:         true
      )
  
      set_flash(:success, "Cliente potencial '#{nombre}' creado")
      redirect t("/leads")
    end
  
    # --- Form edición ---
    get "/leads/:id/editar" do
      @current_page = "leads"
      @lead = tenant_db(:leads).where(id: params[:id]).first
  
      halt 404, "Lead no encontrado" unless @lead
  
      @page_title = "Editar cliente potencial"
      @usuarios   = tenant_db(:usuarios).where(activo: true).order(:nombre).all
      erb :"crm/leads/editar"
    end
  
    # --- Actualizar ---
    post "/leads/:id" do
      lead = tenant_db(:leads).where(id: params[:id]).first
      halt 404, "Lead no encontrado" unless lead
  
      nombre   = params[:nombre].to_s.strip
      empresa  = params[:empresa].to_s.strip
      email    = params[:email].to_s.strip
      telefono = params[:telefono].to_s.strip
      origen   = params[:origen].to_s.strip
      estado   = params[:estado].to_s.strip
      notas    = params[:notas].to_s.strip
  
      if nombre.empty?
        set_flash(:error, "El nombre es obligatorio")
        redirect t("/leads/#{lead[:id]}/editar")
      end
  
      estado = lead[:estado] unless ESTADOS.include?(estado)
  
      DB[:leads].where(id: lead[:id]).update(
        nombre:         nombre,
        empresa:        empresa.empty? ? nil : empresa,
        email:          email.empty? ? nil : email,
        telefono:       telefono.empty? ? nil : telefono,
        origen:         origen.empty? ? nil : origen,
        estado:         estado,
        notas:          notas.empty? ? nil : notas,
        responsable_id: params[:responsable_id].to_s.empty? ? lead[:responsable_id] : params[:responsable_id].to_i,
        activo:         params[:activo] == "1",
        updated_at:     Sequel::CURRENT_TIMESTAMP
      )
  
      set_flash(:success, "Cliente potencial actualizado")
      redirect t("/leads")
    end
  
    # --- Soft delete ---
    post "/leads/:id/eliminar" do
      lead = tenant_db(:leads).where(id: params[:id]).first
      halt 404, "Lead no encontrado" unless lead
  
      DB[:leads].where(id: lead[:id]).update(
        activo:     false,
        updated_at: Sequel::CURRENT_TIMESTAMP
      )
  
      set_flash(:success, "Lead '#{lead[:nombre]}' eliminado")
      redirect t("/leads")
    end
  
    # --- Convertir a cliente ---
    post "/leads/:id/convertir" do
      lead = tenant_db(:leads).where(id: params[:id]).first
      halt 404, "Lead no encontrado" unless lead
  
      if lead[:convertido_a_cliente_id]
        set_flash(:error, "Este lead ya fue convertido")
        redirect t("/leads")
      end
  
      # Crear cliente con los datos del lead
      cliente_id = DB[:clientes].insert(
        tenant_id:  current_tenant_id,
        tipo:       lead[:empresa] ? "empresa" : "persona",
        nombre:     lead[:empresa] || lead[:nombre],
        email:      lead[:email],
        telefono:   lead[:telefono],
        notas:      "Convertido desde lead ##{lead[:id]}",
        activo:     true,
        created_by: current_user[:id]
      )
  
      # Actualizar el lead
      DB[:leads].where(id: lead[:id]).update(
        estado:                  "convertido",
        convertido_a_cliente_id: cliente_id,
        updated_at:              Sequel::CURRENT_TIMESTAMP
      )
  
      set_flash(:success, "Lead convertido en cliente")
      redirect t("/clientes/#{cliente_id}/editar")
    end
  end