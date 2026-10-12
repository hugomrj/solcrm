require_relative "env_helper"

# scripts/crear_estructura.rb
#
#   bundle exec ruby scripts/crear_estructura.rb

ROLES = [
  ["admin",    "Acceso total al tenant"],
  ["vendedor", "Clientes, leads, pipeline, actividades, ventas"],
  ["soporte",  "Tickets y lectura de clientes"]
].freeze

PERMISOS = %w[
  dashboard pipeline clientes contactos leads
  calendario tareas llamadas
  propuestas presupuestos facturas pagos notas_credito articulos_venta
  soporte suscripciones
  proyectos proveedores ordenes_compra contratos_compra
  productos stock ajustes_inventario gastos
  explorador compartir
  informes_ventas informes_gastos informes_pipeline informes_actividad
  usuarios roles configuracion
].freeze

PERMISOS_POR_ROL = {
  "vendedor" => %w[
    dashboard pipeline clientes contactos leads
    calendario tareas llamadas
    propuestas presupuestos facturas pagos notas_credito articulos_venta
    proyectos
    informes_ventas informes_pipeline informes_actividad
  ],
  "soporte" => %w[
    dashboard clientes contactos soporte
    calendario tareas llamadas
  ]
}.freeze

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

# 4. Insertar permisos
PERMISOS.each do |modulo|
  conn.exec_params(
    <<~SQL,
      INSERT INTO permisos (modulo, descripcion)
      VALUES ($1, $2)
      ON CONFLICT (modulo) DO NOTHING
    SQL
    [modulo, modulo.tr("_", " ").capitalize]
  )
end
puts "✅ Permisos creados: #{PERMISOS.size} módulos"

# 5. Asignar permisos a admin (todos)
admin_id = conn.exec_params("SELECT id FROM roles WHERE nombre = $1", ["admin"])[0]["id"]

PERMISOS.each do |modulo|
  permiso_id = conn.exec_params("SELECT id FROM permisos WHERE modulo = $1", [modulo])[0]["id"]

  conn.exec_params(
    <<~SQL,
      INSERT INTO roles_permisos (rol_id, permiso_id)
      VALUES ($1, $2)
      ON CONFLICT (rol_id, permiso_id) DO NOTHING
    SQL
    [admin_id, permiso_id]
  )
end
puts "✅ Admin: todos los permisos"

# 6. Asignar permisos a vendedor y soporte
PERMISOS_POR_ROL.each do |rol_nombre, modulos|
  rol_id = conn.exec_params("SELECT id FROM roles WHERE nombre = $1", [rol_nombre])[0]["id"]

  modulos.each do |modulo|
    permiso_id = conn.exec_params("SELECT id FROM permisos WHERE modulo = $1", [modulo])[0]["id"]
    next unless permiso_id

    conn.exec_params(
      <<~SQL,
        INSERT INTO roles_permisos (rol_id, permiso_id)
        VALUES ($1, $2)
        ON CONFLICT (rol_id, permiso_id) DO NOTHING
      SQL
      [rol_id, permiso_id]
    )
  end

  puts "✅ #{rol_nombre.capitalize}: #{modulos.size} permisos"
end

conn.close
puts
puts "Estructura lista."