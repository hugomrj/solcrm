# modules/usuario/routes.rb

class UsuarioRoutes < BaseApp
  DUMMY_HASH = BCrypt::Password.create("dummy").freeze

  # ============================================================
  # AUTENTICACIÓN
  # ============================================================

  get "/" do
    if tenant
      redirect(authenticated? ? t("/dashboard") : t("/login"))
    else
      "SolCRM. Pedile la URL de tu empresa al administrador."
    end
  end

  get "/login" do
    halt 404, "Necesitás acceder con la URL de tu empresa" unless tenant
    redirect t("/dashboard") if authenticated?
    erb :"usuario/login", layout: false
  end

  post "/login" do
    halt 404, "Necesitás acceder con la URL de tu empresa" unless tenant

    usuario = DB[:usuarios]
      .where(tenant_id: tenant[:id], usuario: params[:username], activo: true)
      .first

    hash = usuario ? usuario[:password_hash] : DUMMY_HASH

    if usuario && BCrypt::Password.new(hash) == params[:password]
      session.clear
      session[:user_id]   = usuario[:id]
      session[:tenant_id] = usuario[:tenant_id]
      set_flash(:success, "¡Bienvenido de nuevo a SolCRM!")
      redirect t("/dashboard")
    end

    set_flash(:error, "Usuario o contraseña incorrectos")
    redirect t("/login")
  end

  post "/logout" do
    session.clear
    set_flash(:success, "Sesión cerrada correctamente")
    redirect t("/login")
  end

  # ============================================================
  # PERFIL PROPIO (cualquier usuario logueado)
  # ============================================================

  get "/perfil" do
    require_login
    @current_page = "perfil"
    @page_title   = "Mi perfil"
    @usuario      = current_user
    erb :"usuario/perfil"
  end

  post "/perfil" do
    require_login

    nombre = params[:nombre].to_s.strip
    email  = params[:email].to_s.strip

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/perfil")
    end

    DB[:usuarios].where(id: current_user[:id]).update(
      nombre:     nombre,
      email:      email.empty? ? nil : email,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Datos actualizados")
    redirect t("/perfil")
  end

  post "/perfil/password" do
    require_login

    actual       = params[:password_actual].to_s
    nueva        = params[:password_nueva].to_s
    confirmacion = params[:password_confirmacion].to_s

    if actual.empty? || nueva.empty? || confirmacion.empty?
      set_flash(:error, "Completá todos los campos")
      redirect t("/perfil")
    end

    if BCrypt::Password.new(current_user[:password_hash]) != actual
      set_flash(:error, "La contraseña actual es incorrecta")
      redirect t("/perfil")
    end

    if nueva.length < 6
      set_flash(:error, "La nueva contraseña debe tener al menos 6 caracteres")
      redirect t("/perfil")
    end

    if nueva != confirmacion
      set_flash(:error, "Las contraseñas no coinciden")
      redirect t("/perfil")
    end

    DB[:usuarios].where(id: current_user[:id]).update(
      password_hash: BCrypt::Password.create(nueva),
      updated_at:    Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Contraseña actualizada")
    redirect t("/perfil")
  end

  # ============================================================
  # GESTIÓN DE USUARIOS (solo admin)
  # ============================================================

  before do
    require_admin if request.path_info.start_with?("/usuarios")
  end

  # --- Listado ---
  get "/usuarios" do
    @current_page = "usuarios"
    @page_title   = "Usuarios"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:usuarios)

    case params[:estado]
    when "activos"   then dataset = dataset.where(activo: true)
    when "inactivos" then dataset = dataset.where(activo: false)
    end

    q = params[:q].to_s.strip
    unless q.empty?
      patron = "%#{q}%"
      dataset = dataset.where(
        Sequel.ilike(:usuario, patron) |
        Sequel.ilike(:nombre,  patron) |
        Sequel.ilike(:email,   patron)
      )
    end

    @usuarios = dataset.order(:usuario).paginate(page, 25)
    @filtros  = { q: q, estado: params[:estado] }

    erb :"usuario/index"
  end

  # --- Form alta ---
  get "/usuarios/nuevo" do
    @current_page  = "usuarios"
    @page_title    = "Nuevo usuario"
    @usuario       = nil
    @roles_usuario = []

    erb :"usuario/nuevo"
  end

  # --- Crear ---
  post "/usuarios" do
    usuario  = params[:usuario].to_s.strip
    nombre   = params[:nombre].to_s.strip
    email    = params[:email].to_s.strip
    password = params[:password].to_s

    if usuario.empty? || nombre.empty? || password.empty?
      set_flash(:error, "Usuario, nombre y contraseña son obligatorios")
      redirect t("/usuarios/nuevo")
    end

    if tenant_db(:usuarios).where(usuario: usuario).count > 0
      set_flash(:error, "Ya existe un usuario con ese nombre en esta empresa")
      redirect t("/usuarios/nuevo")
    end

    usuario_id = DB[:usuarios].insert(
      tenant_id:     current_tenant_id,
      usuario:       usuario,
      nombre:        nombre,
      email:         email.empty? ? nil : email,
      password_hash: BCrypt::Password.create(password),
      activo:        true
    )

    asignar_roles(usuario_id, params[:roles])

    set_flash(:success, "Usuario '#{usuario}' creado")
    redirect t("/usuarios")
  end

  # --- Form edición ---
  get "/usuarios/:id/editar" do
    @current_page = "usuarios"
    @usuario = tenant_db(:usuarios).where(id: params[:id]).first

    halt 404, "Usuario no encontrado" unless @usuario

    @page_title    = "Editar usuario"
    @roles_usuario = DB[:usuarios_roles]
      .join(:roles, id: :rol_id)
      .where(usuario_id: @usuario[:id])
      .select_map(Sequel[:roles][:nombre])

    erb :"usuario/editar"
  end

  # --- Actualizar ---
  post "/usuarios/:id" do
    usuario = tenant_db(:usuarios).where(id: params[:id]).first
    halt 404, "Usuario no encontrado" unless usuario

    nombre = params[:nombre].to_s.strip
    email  = params[:email].to_s.strip
    pass   = params[:password].to_s

    if nombre.empty?
      set_flash(:error, "El nombre es obligatorio")
      redirect t("/usuarios/#{usuario[:id]}/editar")
    end

    campos = {
      nombre:     nombre,
      email:      email.empty? ? nil : email,
      activo:     params[:activo] == "1",
      updated_at: Sequel::CURRENT_TIMESTAMP
    }

    campos[:password_hash] = BCrypt::Password.create(pass) unless pass.empty?

    DB[:usuarios].where(id: usuario[:id]).update(campos)

    asignar_roles(usuario[:id], params[:roles])

    set_flash(:success, "Usuario actualizado")
    redirect t("/usuarios")
  end

  # --- Soft delete ---
  post "/usuarios/:id/eliminar" do
    usuario = tenant_db(:usuarios).where(id: params[:id]).first
    halt 404, "Usuario no encontrado" unless usuario

    if usuario[:id] == current_user[:id]
      set_flash(:error, "No podés eliminarte a vos mismo")
      redirect t("/usuarios")
    end

    DB[:usuarios].where(id: usuario[:id]).update(
      activo:     false,
      updated_at: Sequel::CURRENT_TIMESTAMP
    )

    set_flash(:success, "Usuario '#{usuario[:usuario]}' eliminado")
    redirect t("/usuarios")
  end

  # ============================================================
  # Helpers internos
  # ============================================================

  helpers do
    def asignar_roles(usuario_id, roles_params)
      DB[:usuarios_roles].where(usuario_id: usuario_id).delete

      return unless roles_params

      roles_params = [roles_params] unless roles_params.is_a?(Array)

      roles_params.each do |rol_nombre|
        rol_id = DB[:roles].where(nombre: rol_nombre).get(:id)
        next unless rol_id

        DB[:usuarios_roles].insert(
          tenant_id:  current_tenant_id,
          usuario_id: usuario_id,
          rol_id:     rol_id
        )
      end
    end
  end
end