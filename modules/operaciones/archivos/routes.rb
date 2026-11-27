# modules/operaciones/archivos/routes.rb
#
# Los archivos NO se guardan en public/: van a storage/archivos/<tenant_id>/ y
# se sirven por una ruta autenticada con send_file.

require "fileutils"
require "securerandom"

class ArchivosRoutes < BaseApp
  before do
    if request.path_info.start_with?("/explorador")
      require_login
      halt 403, "Sin permiso para acceder a Archivos" unless puede?(:explorador)
    end
  end

  # --- Listado ---
  get "/explorador" do
    @current_page = "explorador"
    @page_title   = "Explorador de archivos"

    page = (params[:page] || 1).to_i
    page = 1 if page < 1

    dataset = tenant_db(:archivos)

    q = params[:q].to_s.strip
    unless q.empty?
      dataset = dataset.where(Sequel.ilike(:nombre, "%#{q}%"))
    end

    @archivos = dataset.order(Sequel.desc(:created_at), Sequel.desc(:id)).paginate(page, ITEMS_POR_PAGINA)
    @usuarios_por_id = cargar_por_id(:usuarios, @archivos.map { |a| a[:usuario_id] })
    @total_bytes = tenant_db(:archivos).sum(:tamano).to_i
    @filtros = { q: q }

    erb :"operaciones/archivos/index"
  end

  # --- Subir ---
  post "/explorador" do
    archivo = params[:archivo]

    unless archivo.is_a?(Hash) && archivo[:tempfile]
      set_flash(:error, "Elegí un archivo")
      redirect t("/explorador")
    end

    nombre_original = File.basename(archivo[:filename].to_s)
    if nombre_original.empty?
      set_flash(:error, "El archivo no tiene nombre válido")
      redirect t("/explorador")
    end

    extension = File.extname(nombre_original)
    base      = File.basename(nombre_original, extension).gsub(/[^0-9A-Za-z._-]/, "_")[0, 80]
    guardado  = "#{Time.now.to_i}-#{SecureRandom.hex(4)}-#{base}#{extension}"

    dir = File.join(storage_root, current_tenant_id.to_s)
    FileUtils.mkdir_p(dir)

    destino = File.join(dir, guardado)
    File.open(destino, "wb") { |f| f.write(archivo[:tempfile].read) }

    DB[:archivos].insert(
      tenant_id:  current_tenant_id,
      nombre:     nombre_original,
      path:       "#{current_tenant_id}/#{guardado}",
      tipo_mime:  archivo[:type],
      tamano:     File.size(destino),
      usuario_id: current_user ? current_user[:id] : nil
    )

    set_flash(:success, "Archivo '#{nombre_original}' subido")
    redirect t("/explorador")
  end

  # --- Descargar ---
  get "/explorador/:id/descargar" do
    archivo = tenant_db(:archivos).where(id: params[:id]).first
    halt 404, "Archivo no encontrado" unless archivo

    ruta = File.join(storage_root, archivo[:path])
    halt 404, "El archivo no está en disco" unless File.exist?(ruta)

    send_file ruta,
              filename: archivo[:nombre],
              type:     archivo[:tipo_mime].to_s.empty? ? "application/octet-stream" : archivo[:tipo_mime]
  end

  helpers do
    def storage_root
      File.join(settings.root, "storage", "archivos")
    end

    def formato_tamano(bytes)
      b = bytes.to_f
      return "—" if b <= 0
      return "#{b.round} B" if b < 1024
      return "#{(b / 1024).round(1)} KB" if b < 1024 * 1024

      "#{(b / 1024 / 1024).round(1)} MB"
    end
  end
end
