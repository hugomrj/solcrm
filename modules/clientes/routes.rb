class ClientesRoutes < BaseApp
    # ============================================================
    # GESTIÓN DE CLIENTES (cualquier usuario logueado)
    # ============================================================
  
    before do
      require_login if request.path_info.start_with?("/clientes")
    end
  
    # --- Listado ---
    get "/clientes" do
      @current_page = "clientes"
      @page_title   = "Clientes"
  
      page = (params[:page] || 1).to_i
      page = 1 if page < 1
  
      dataset = tenant_db(:clientes)
  
      # Filtro por estado
      case params[:estado]
      when "activos"   then dataset = dataset.where(activo: true)
      when "inactivos" then dataset = dataset.where(activo: false)
      end
  
      # Filtro por tipo
      if %w[empresa persona].include?(params[:tipo])
        dataset = dataset.where(tipo: params[:tipo])
      end
  
      # Búsqueda
      q = params[:q].to_s.strip
      unless q.empty?
        patron = "%#{q}%"
        dataset = dataset.where(
          Sequel.ilike(:nombre,    patron) |
          Sequel.ilike(:documento, patron) |
          Sequel.ilike(:email,     patron) |
          Sequel.ilike(:telefono,  patron)
        )
      end
  
      @clientes = dataset.order(:nombre).paginate(page, 25)
      @filtros  = { q: q, estado: params[:estado], tipo: params[:tipo] }
  
      erb :"clientes/index"
    end
  
    # --- Form alta ---
    get "/clientes/nuevo" do
      @current_page = "clientes"
      @page_title   = "Nuevo cliente"
      @cliente      = nil
      erb :"clientes/nuevo"
    end
  
    # --- Crear ---
    post "/clientes" do
      tipo      = params[:tipo].to_s.strip
      nombre    = params[:nombre].to_s.strip
      documento = params[:documento].to_s.strip
      email     = params[:email].to_s.strip
      telefono  = params[:telefono].to_s.strip
      direccion = params[:direccion].to_s.strip
      notas     = params[:notas].to_s.strip
  
      if nombre.empty?
        set_flash(:error, "El nombre es obligatorio")
        redirect t("/clientes/nuevo")
      end
  
      # Verificar documento duplicado en el mismo tenant
      unless documento.empty?
        if tenant_db(:clientes).where(documento: documento).count > 0
          set_flash(:error, "Ya existe un cliente con ese documento en esta empresa")
          redirect t("/clientes/nuevo")
        end
      end
  
      DB[:clientes].insert(
        tenant_id: current_tenant_id,
        tipo:      tipo.empty? ? "empresa" : tipo,
        nombre:    nombre,
        documento: documento.empty? ? nil : documento,
        email:     email.empty? ? nil : email,
        telefono:  telefono.empty? ? nil : telefono,
        direccion: direccion.empty? ? nil : direccion,
        notas:     notas.empty? ? nil : notas,
        activo:    true,
        created_by: current_user[:id]
      )
  
      set_flash(:success, "Cliente '#{nombre}' creado")
      redirect t("/clientes")
    end
  
    # --- Form edición ---
    get "/clientes/:id/editar" do
      @current_page = "clientes"
      @cliente = tenant_db(:clientes).where(id: params[:id]).first
  
      halt 404, "Cliente no encontrado" unless @cliente
  
      @page_title = "Editar cliente"
      erb :"clientes/editar"
    end
  
    # --- Actualizar ---
    post "/clientes/:id" do
      cliente = tenant_db(:clientes).where(id: params[:id]).first
      halt 404, "Cliente no encontrado" unless cliente
  
      tipo      = params[:tipo].to_s.strip
      nombre    = params[:nombre].to_s.strip
      documento = params[:documento].to_s.strip
      email     = params[:email].to_s.strip
      telefono  = params[:telefono].to_s.strip
      direccion = params[:direccion].to_s.strip
      notas     = params[:notas].to_s.strip
  
      if nombre.empty?
        set_flash(:error, "El nombre es obligatorio")
        redirect t("/clientes/#{cliente[:id]}/editar")
      end
  
      # Verificar documento duplicado (excepto el propio)
      unless documento.empty?
        duplicado = tenant_db(:clientes)
          .where(documento: documento)
          .exclude(id: cliente[:id])
          .count
  
        if duplicado > 0
          set_flash(:error, "Ya existe otro cliente con ese documento")
          redirect t("/clientes/#{cliente[:id]}/editar")
        end
      end
  
      DB[:clientes].where(id: cliente[:id]).update(
        tipo:       tipo.empty? ? "empresa" : tipo,
        nombre:     nombre,
        documento:  documento.empty? ? nil : documento,
        email:      email.empty? ? nil : email,
        telefono:   telefono.empty? ? nil : telefono,
        direccion:  direccion.empty? ? nil : direccion,
        notas:      notas.empty? ? nil : notas,
        activo:     params[:activo] == "1",
        updated_at: Sequel::CURRENT_TIMESTAMP
      )
  
      set_flash(:success, "Cliente actualizado")
      redirect t("/clientes")
    end
  
    # --- Soft delete ---
    post "/clientes/:id/eliminar" do
      cliente = tenant_db(:clientes).where(id: params[:id]).first
      halt 404, "Cliente no encontrado" unless cliente
  
      DB[:clientes].where(id: cliente[:id]).update(
        activo:     false,
        updated_at: Sequel::CURRENT_TIMESTAMP
      )
  
      set_flash(:success, "Cliente '#{cliente[:nombre]}' eliminado")
      redirect t("/clientes")
    end
  end