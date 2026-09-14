# config/routes.rb

require_relative "../modules/usuario/routes"
require_relative "../modules/clientes_potenciales/routes"

# Dashboard
get "/dashboard" do
    @current_page = 'dashboard'
    @page_title = 'Panel de Control'
    
    # FORZAMOS el uso del layout que está en la subcarpeta
    erb :index, layout: :"layout/layout"
  end
  
  get "/partials/menu-ventas" do
    erb :"layout/partials/_submenu_ventas", layout: false
  end
