# config/routes.rb

require_relative "../modules/auth/usuario/routes"
require_relative "../modules/crm/clientes/routes"
require_relative "../modules/crm/contactos/routes"
require_relative "../modules/crm/leads/routes"
require_relative "../modules/crm/pipeline/routes"
require_relative "../modules/sistema/dashboard/routes"

SolCRM.use UsuarioRoutes
SolCRM.use ClientesRoutes
SolCRM.use ContactosRoutes
SolCRM.use LeadsRoutes
SolCRM.use PipelineRoutes
SolCRM.use DashboardRoutes