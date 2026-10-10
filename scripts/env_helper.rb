require "pg"

# scripts/env_helper.rb
#
# Helper compartido. Carga .env y ofrece conexión a la DB.

def cargar_env
  env_file = File.expand_path("../.env", __dir__)
  abort "ERROR: No existe el archivo .env" unless File.exist?(env_file)

  File.readlines(env_file).each do |line|
    line.strip!
    next if line.empty? || line.start_with?("#")
    key, value = line.split("=", 2)
    ENV[key] = value if key && value
  end
end

def conectar_db(dbname: nil)
  PG.connect(
    host:     ENV.fetch("DB_HOST", "localhost"),
    port:     ENV.fetch("DB_PORT", "5432"),
    dbname:   dbname || ENV.fetch("DB_NAME"),
    user:     ENV.fetch("DB_USER"),
    password: ENV.fetch("DB_PASSWORD")
  )
end

def db_existe?(database)
  conn = conectar_db(dbname: "postgres")
  exists = conn.exec_params(
    "SELECT 1 FROM pg_database WHERE datname = $1", [database]
  ).any?
  conn.close
  exists
end

cargar_env