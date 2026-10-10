# modules/dashboard/routes.rb

class DashboardRoutes < BaseApp
  before "/dashboard" do
    require_login
  end


  get "/dashboard" do
    @current_page = "dashboard"
    @page_title   = "Panel de Control"
    erb :"dashboard/index"
  end


  get "/partials/menu-ventas" do
    require_login
    erb :"layout/partials/_submenu_ventas", layout: false
  end
end