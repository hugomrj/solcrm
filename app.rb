# app.rb

require "sinatra/base"
require "bcrypt"

require_relative "lib/db"
require_relative "helpers/auth_helpers"
require_relative "helpers/flash_helpers"
require_relative "helpers/ventas_helpers"
require_relative "helpers/inventario_helpers"
require_relative "helpers/informes_helpers"
require_relative "helpers/pdf_helpers"


class BaseApp < Sinatra::Base
  set :root,          File.dirname(__FILE__)
  set :public_folder, File.join(settings.root, "public")
  set :views,         File.join(settings.root, "views")
  set :erb,           layout: :"layout/base"

  set :sessions, false

  configure :development do
    set :show_exceptions, true
    set :logging,         true
  end


  # Rutas que NO llevan slug de tenant
  NON_TENANT = %w[css js images favicon.ico super doc ayuda].freeze

  # Filas por página en todos los listados paginados (.paginate)
  ITEMS_POR_PAGINA = 12

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


  # ---- Doc técnica (estática) ----
  get "/doc" do
    send_file File.join(settings.root, "doc", "index.html")
  end

  # ---- Guía de uso para el usuario final (estática, sin login) ----
  get "/ayuda/?" do
    send_file File.join(settings.root, "public", "ayuda", "index.html")
  end


  helpers AuthHelpers
  helpers FlashHelpers
  helpers VentasHelpers
  helpers InventarioHelpers
  helpers InformesHelpers
  helpers PdfHelpers
end

class SolCRM < BaseApp
end

require_relative "config/routes"