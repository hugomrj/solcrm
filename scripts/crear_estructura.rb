require_relative "env_helper"

# scripts/crear_estructura.rb
#
#   bundle exec ruby scripts/crear_estructura.rb

ROLES = [
  ["admin",    "Acceso total al tenant"],
  ["vendedor", "Clientes, leads, pipeline, actividades"],
  ["soporte",  "Tickets y lectura de clientes"]
].freeze

database = ENV.fetch("DB_NAME")

# 1. Crear la DB si no existe
if db_existe?(database)
  puts "✓ Base de datos ya existe: #{database}"
else
  conn = conectar_db(dbname: "postgres")
  conn.exec("CREATE DATABASE \"#{database}\"")
  conn.close
  puts "✅ Base de datos creada: #{database}"
end

# 2. Aplicar schema.sql
conn = conectar_db
schema_file = File.expand_path("schema.sql", __dir__)
conn.exec(File.read(schema_file))
puts "✅ Tablas creadas"

# 3. Insertar roles
ROLES.each do |nombre, descripcion|
  conn.exec_params(
    <<~SQL,
      INSERT INTO roles (nombre, descripcion)
      VALUES ($1, $2)
      ON CONFLICT (nombre) DO NOTHING
    SQL
    [nombre, descripcion]
  )
end
puts "✅ Roles creados: admin, vendedor, soporte"

conn.close
puts
puts "Estructura lista."