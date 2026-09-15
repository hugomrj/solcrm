# modules/dashboard/routes.rb

before "/dashboard" do
  require_login
end

get "/dashboard" do
  @current_page = "dashboard"
  @page_title = "Panel de Control"

  # ✅ Cambiado de :"layout/layout" a :"layout/base"
  erb :"dashboard/index", layout: :"layout/base"
end

get "/partials/menu-ventas" do
  require_login
  erb :"layout/partials/_submenu_ventas", layout: false
end