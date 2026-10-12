require "bcrypt"
require_relative "env_helper"

# scripts/crear_dios.rb
#
#   bundle exec ruby scripts/crear_dios.rb
#   bundle exec ruby scripts/crear_dios.rb <usuario> <password> [email]
#
# Sin argumentos: lee de .env (SUPER_ADMIN_USER, SUPER_ADMIN_PASSWORD, SUPER_ADMIN_EMAIL)
# Con argumentos: usa los pasados por línea de comandos

usuario  = ARGV[0] || ENV.fetch("SUPER_ADMIN_USER", nil)
password = ARGV[1] || ENV.fetch("SUPER_ADMIN_PASSWORD", nil)
email    = ARGV[2] || ENV.fetch("SUPER_ADMIN_EMAIL", nil)

if usuario.nil? || password.nil?
  abort <<~MSG
    ERROR: Faltan credenciales.
    Agregá al .env:
      SUPER_ADMIN_USER=dios
      SUPER_ADMIN_PASSWORD=tu_password
      SUPER_ADMIN_EMAIL=dios@solcrm.local
    O corré:
      bundle exec ruby scripts/crear_dios.rb dios tu_password
  MSG
end

email ||= "#{usuario}@solcrm.local"

conn = conectar_db

conn.exec_params(
  <<~SQL,
    INSERT INTO super_admins (usuario, email, password_hash, nombre)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (usuario) DO UPDATE
      SET password_hash = EXCLUDED.password_hash
    RETURNING id
  SQL
  [usuario, email, BCrypt::Password.create(password), "Dios"]
)

conn.close

puts "✅ Super admin '#{usuario}' listo"
puts "   URL:      /super/login"
puts "   Usuario:  #{usuario}"
puts "   Password: #{password}"
puts "   Email:    #{email}"