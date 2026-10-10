require "bcrypt"
require_relative "env_helper"

# scripts/crear_tenant.rb
#
#   bundle exec ruby scripts/crear_tenant.rb <codigo> <usuario> <password>
#
# Ejemplo:
#   bundle exec ruby scripts/crear_tenant.rb acme admin admin

codigo, usuario, password = ARGV

if codigo.nil? || usuario.nil? || password.nil?
  abort "Uso: bundle exec ruby scripts/crear_tenant.rb <codigo> <usuario> <password>"
end

conn = conectar_db

# 1. Tenant
result = conn.exec_params(
  <<~SQL,
    INSERT INTO tenants (codigo, nombre)
    VALUES ($1, $2)
    ON CONFLICT (codigo) DO UPDATE SET nombre = EXCLUDED.nombre
    RETURNING id
  SQL
  [codigo, codigo.capitalize]
)
tenant_id = result[0]["id"]

# 2. Usuario admin
result = conn.exec_params(
  <<~SQL,
    INSERT INTO usuarios (tenant_id, usuario, email, password_hash, nombre)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (tenant_id, usuario) DO UPDATE
      SET password_hash = EXCLUDED.password_hash
    RETURNING id
  SQL
  [tenant_id, usuario, "#{usuario}@#{codigo}.local",
   BCrypt::Password.create(password), "Admin"]
)
usuario_id = result[0]["id"]

# 3. Rol admin
conn.exec_params(
  <<~SQL,
    INSERT INTO usuarios_roles (tenant_id, usuario_id, rol_id)
    SELECT $1, $2, id FROM roles WHERE nombre = 'admin'
    ON CONFLICT (usuario_id, rol_id) DO NOTHING
  SQL
  [tenant_id, usuario_id]
)

conn.close

puts "✅ Tenant '#{codigo}' creado"
puts "   URL:     /#{codigo}/login"
puts "   Usuario: #{usuario}"
puts "   Password: #{password}"