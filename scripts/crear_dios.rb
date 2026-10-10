require "bcrypt"
require_relative "env_helper"

# scripts/crear_dios.rb
#
#   bundle exec ruby scripts/crear_dios.rb <usuario> <password> [email]
#
# Ejemplo:
#   bundle exec ruby scripts/crear_dios.rb dios mipassword
#   bundle exec ruby scripts/crear_dios.rb dios mipassword dios@solcrm.com

usuario, password, email = ARGV

if usuario.nil? || password.nil?
  abort "Uso: bundle exec ruby scripts/crear_dios.rb <usuario> <password> [email]"
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

puts "✅ Super admin creado"
puts "   URL:      /super/login"
puts "   Usuario:  #{usuario}"
puts "   Password: #{password}"
puts "   Email:    #{email}"