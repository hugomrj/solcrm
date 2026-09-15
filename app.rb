# app.rb

require "sinatra"
require "sequel"
require "bcrypt"
require "dotenv/load"

# Configuración
set :root, File.dirname(__FILE__)
set :public_folder, File.join(settings.root, "public")
set :views, File.join(settings.root, "views")

# Sesiones
enable :sessions

# Base de datos
DB = Sequel.connect(
  adapter: "postgres",
  host: ENV.fetch("DB_HOST"),
  port: ENV.fetch("DB_PORT"),
  database: ENV.fetch("DB_NAME"),
  user: ENV.fetch("DB_USER"),
  password: ENV.fetch("DB_PASSWORD")
)

# Requerir los helpers (se registran automáticamente gracias a 'helpers do')
require_relative "helpers/auth_helpers"
require_relative "helpers/flash_helpers"

# Cargar las rutas
require_relative "config/routes"