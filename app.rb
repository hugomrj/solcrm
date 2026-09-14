# app.rb
require "sinatra"

# Configuración absoluta a prueba de fallos
set :root, File.dirname(__FILE__)
set :public_folder, File.join(settings.root, 'public')
set :views, File.join(settings.root, 'views')

require_relative "helpers/auth_helpers"
require_relative "config/routes"