# modules/crm/inventario/productos/routes.rb
#
# No existe tabla `productos`: el catálogo es `articulos`, que se divide por
# `tipo` (producto | servicio). "Productos" es entonces la vista filtrada del
# catálogo, así que redirigimos en lugar de duplicar el módulo.

class ProductosRoutes < BaseApp
  before do
    if request.path_info.start_with?("/productos")
      require_login
      halt 403, "Sin permiso para acceder a Productos" unless puede?(:productos)
    end
  end

  get "/productos" do
    redirect t("/ventas/articulos?tipo=producto")
  end
end
