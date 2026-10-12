require_relative "../lib/tenants"

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

Tenants.crear(codigo, usuario, password)

puts "✅ Tenant '#{codigo}' creado"
puts "   URL:      /#{codigo}/login"
puts "   Usuario:  #{usuario}"
puts "   Password: #{password}"
puts "   Etapas:   6 (Contacto inicial → Calificación → Propuesta → Negociación → Ganada → Perdida)"