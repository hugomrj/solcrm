#!/usr/bin/env ruby
# scripts/migrar.rb
#
# Aplica migraciones incrementales sobre una base EXISTENTE, sin borrar datos.
# A diferencia de crear_estructura.rb (que hace DROP de todo y recrea).
#
# Uso:
#   bundle exec ruby scripts/migrar.rb
#
# Cómo funciona:
#   - Lee scripts/migraciones/*.sql ordenados por nombre.
#   - Registra cada archivo aplicado en la tabla schema_migrations.
#   - Los archivos deben ser idempotentes (CREATE TABLE IF NOT EXISTS, etc.).

require "sequel"
require "dotenv/load"

DB = Sequel.connect(
  adapter:  "postgres",
  host:     ENV.fetch("DB_HOST"),
  port:     ENV.fetch("DB_PORT"),
  database: ENV.fetch("DB_NAME"),
  user:     ENV.fetch("DB_USER"),
  password: ENV.fetch("DB_PASSWORD")
)

DB.create_table?(:schema_migrations) do
  String :version, primary_key: true
  Time   :applied_at, null: false, default: Sequel::CURRENT_TIMESTAMP
end

directorio = File.join(__dir__, "migraciones")
archivos   = Dir[File.join(directorio, "*.sql")].sort

if archivos.empty?
  puts "No hay migraciones en scripts/migraciones/"
  exit 0
end

aplicadas = DB[:schema_migrations].select_map(:version)

pendientes = archivos.reject { |path| aplicadas.include?(File.basename(path)) }

if pendientes.empty?
  puts "Base al día: #{aplicadas.size} migración(es) aplicadas, nada pendiente."
  exit 0
end

pendientes.each do |path|
  version = File.basename(path)
  sql     = File.read(path)

  print "Aplicando #{version}… "
  begin
    DB.transaction do
      DB.run(sql)
      DB[:schema_migrations].insert(version: version)
    end
    puts "OK"
  rescue => e
    puts "ERROR"
    warn "  #{e.class}: #{e.message}"
    exit 1
  end
end

puts "Listo. #{pendientes.size} migración(es) nueva(s) aplicadas."
