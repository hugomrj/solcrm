# modules/operaciones/archivos/compartir.rb
#
# "Compartir" no está modelado todavía: no hay tabla de enlaces ni permisos por
# archivo. Queda como redirect al explorador y fuera del menú.

class CompartirRoutes < BaseApp
  before do
    if request.path_info.start_with?("/compartir")
      require_login
    end
  end

  get "/compartir" do
    redirect t("/explorador")
  end
end
