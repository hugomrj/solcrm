# app.rb
require "sinatra/base"
require "bcrypt"

require_relative "lib/db"
require_relative "helpers/auth_helpers"
require_relative "helpers/flash_helpers"


class BaseApp < Sinatra::Base
  set :root,          File.dirname(__FILE__)
  set :public_folder, File.join(settings.root, "public")
  set :views,         File.join(settings.root, "views")
  set :erb,           layout: :"layout/base"

  set :sessions,       true
  set :session_secret, ENV.fetch("SESSION_SECRET")

  configure :development do
    set :show_exceptions, true
    set :logging,         true
  end

  # Rutas que NO llevan slug de tenant
  NON_TENANT = %w[css js images favicon.ico super].freeze

  # Extrae el tenant del primer segmento de la URL y reescribe el path
  before do
    next if env["solcrm.tenant_done"]
    env["solcrm.tenant_done"] = true

    segments = request.path_info.split("/").reject(&:empty?)
    first    = segments.first

    next if first.nil?               # "/" raíz
    next if NON_TENANT.include?(first)  # assets y /super

    tenant = DB[:tenants].where(codigo: first, activo: true).first

    if tenant
      env["solcrm.tenant"] = tenant
      resto = segments[1..]
      env["PATH_INFO"] = resto.empty? ? "/" : "/" + resto.join("/")
    else
      halt 404, "Empresa '#{first}' no encontrada"
    end
  end

  helpers AuthHelpers
  helpers FlashHelpers
end

class SolCRM < BaseApp
end

require_relative "config/routes"