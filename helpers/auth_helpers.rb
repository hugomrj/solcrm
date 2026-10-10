# helpers/auth_helpers.rb


module AuthHelpers
  def authenticated?
    !session[:user_id].nil?
  end

  def current_user
    return nil unless authenticated?
    DB[:usuarios].where(id: session[:user_id]).first
  end

  def require_login
    return redirect(t("/login")) unless authenticated?

    user = current_user
    if user.nil? || !user[:activo]
      session.clear
      return redirect(t("/login"))
    end

    # El usuario debe pertenecer al tenant de la URL
    if user[:tenant_id] != current_tenant_id
      session.clear
      return redirect(t("/login"))
    end
  end

  # --- Tenant ---
  def tenant
    env["solcrm.tenant"]
  end

  def tenant_slug
    tenant && tenant[:codigo]
  end

  def current_tenant_id
    tenant && tenant[:id]
  end

  # Prefija el path con el slug del tenant actual:
  #   t("/dashboard") → "/acme/dashboard"
  def t(path)
    return path unless tenant_slug
    "/#{tenant_slug}#{path}"
  end

  # Query filtrada por tenant
  def tenant_db(table)
    DB[table].where(tenant_id: current_tenant_id)
  end

  def current_user_name
    user = current_user
    user ? (user[:nombre] || user[:usuario] || "Usuario") : "Usuario"
  end

  def current_page?(path)
    request.path == path || (@current_page && @current_page.to_s == path.to_s)
  end

  def current_user_roles
    return [] unless current_user
    DB[:usuarios_roles]
      .join(:roles, id: :rol_id)
      .where(usuario_id: current_user[:id])
      .select_map(:nombre)
  end

  def current_user_admin?
    current_user_roles.include?("admin")
  end

  def require_admin
    require_login
    halt 403, "No tenés permiso" unless current_user_admin?
  end


end