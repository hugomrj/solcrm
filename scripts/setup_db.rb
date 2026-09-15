require "pg"
require "bcrypt"

# scripts/setup_db.rb
#
# Ejecutar desde la raíz del proyecto:
#
#   bundle exec ruby scripts/setup_db.rb
#
# El script:
#   1. Lee la configuración desde .env
#   2. Crea la base de datos si no existe
#   3. Crea las tablas
#   4. Crea el usuario demo

def cargar_env
  env_file = File.expand_path("../.env", __dir__)

  unless File.exist?(env_file)
    abort "ERROR: No existe el archivo .env"
  end

  File.readlines(env_file).each do |line|
    line.strip!

    next if line.empty? || line.start_with?("#")

    key, value = line.split("=", 2)
    ENV[key] = value if key && value
  end
end

def crear_usuario_demo(connection)
  usuario = "demo"
  password = "demo"
  password_hash = BCrypt::Password.create(password)

  connection.exec_params(
    <<~SQL,
      INSERT INTO usuarios (usuario, password_hash)
      VALUES ($1, $2)
      ON CONFLICT (usuario) DO NOTHING
    SQL
    [usuario, password_hash]
  )

  puts "Usuario demo creado."
end

cargar_env

host     = ENV.fetch("DB_HOST", "localhost")
port     = ENV.fetch("DB_PORT", "5432")
database = ENV.fetch("DB_NAME")
user     = ENV.fetch("DB_USER")
password = ENV.fetch("DB_PASSWORD")

puts "Verificando base de datos #{database}..."

connection = PG.connect(
  host: host,
  port: port,
  dbname: "postgres",
  user: user,
  password: password
)

exists = connection.exec_params(
  "SELECT 1 FROM pg_database WHERE datname = $1",
  [database]
).any?

unless exists
  connection.exec("CREATE DATABASE \"#{database}\"")
  puts "Base de datos creada."
else
  puts "La base de datos ya existe."
end

connection.close

connection = PG.connect(
  host: host,
  port: port,
  dbname: database,
  user: user,
  password: password
)

schema_file = File.expand_path("schema.sql", __dir__)
connection.exec(File.read(schema_file))

puts "Tablas creadas."

crear_usuario_demo(connection)

connection.close

puts "Base de datos lista."