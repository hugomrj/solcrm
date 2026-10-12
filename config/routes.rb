# config/routes.rb

require_relative "../modules/usuario/routes"
require_relative "../modules/clientes/routes"
require_relative "../modules/clientes_potenciales/routes"
require_relative "../modules/dashboard/routes"

SolCRM.use UsuarioRoutes
SolCRM.use ClientesRoutes
SolCRM.use ClientesPotencialesRoutes
SolCRM.use DashboardRoutes