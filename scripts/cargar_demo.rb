require "bcrypt"
require_relative "../lib/tenants"

# scripts/cargar_demo.rb
#
#   bundle exec ruby scripts/cargar_demo.rb <codigo_tenant>
#
# Ejemplo:
#   bundle exec ruby scripts/cargar_demo.rb acme
#
# Carga datos de prueba en un tenant vacío:
#   - 2 usuarios (vendedor, soporte)
#   - 6 clientes
#   - 5 contactos
#   - 6 leads
#   - 11 oportunidades en distintas etapas
#   - 19 actividades (llamadas, emails, reuniones, notas, tareas)

codigo = ARGV[0]
abort "Uso: bundle exec ruby scripts/cargar_demo.rb <codigo_tenant>" if codigo.nil?

tenant = DB[:tenants].where(codigo: codigo).first
abort "❌ Tenant '#{codigo}' no encontrado" unless tenant
tenant_id = tenant[:id]

if DB[:clientes].where(tenant_id: tenant_id).count > 0
  abort "❌ El tenant '#{codigo}' ya tiene datos. Usá otro tenant o reseteá la DB."
end

admin = DB[:usuarios].where(tenant_id: tenant_id).order(:id).first
abort "❌ El tenant no tiene usuarios" unless admin

etapas = DB[:pipeline_etapas].where(tenant_id: tenant_id).order(:orden).all
abort "❌ El tenant no tiene etapas de pipeline" if etapas.size < 6

etapa_id = ->(nombre) { etapas.find { |e| e[:nombre] == nombre }[:id] }

puts "Cargando datos de demo en '#{codigo}'..."
puts

DB.transaction do
  # ============================================================
  # USUARIOS EXTRA
  # ============================================================
  vendedor_rol = DB[:roles].where(nombre: "vendedor").get(:id)
  soporte_rol  = DB[:roles].where(nombre: "soporte").get(:id)

  vendedor_id = DB[:usuarios]
    .insert_conflict(target: [:tenant_id, :usuario])
    .returning(:id)
    .insert(
      tenant_id:     tenant_id,
      usuario:       "vendedor",
      email:         "vendedor@#{codigo}.local",
      password_hash: BCrypt::Password.create("vendedor"),
      nombre:        "Carlos Vendedor"
    ).first[:id]

  DB[:usuarios_roles]
    .insert_conflict(target: [:usuario_id, :rol_id])
    .insert(tenant_id: tenant_id, usuario_id: vendedor_id, rol_id: vendedor_rol)

  soporte_id = DB[:usuarios]
    .insert_conflict(target: [:tenant_id, :usuario])
    .returning(:id)
    .insert(
      tenant_id:     tenant_id,
      usuario:       "soporte",
      email:         "soporte@#{codigo}.local",
      password_hash: BCrypt::Password.create("soporte"),
      nombre:        "María Soporte"
    ).first[:id]

  DB[:usuarios_roles]
    .insert_conflict(target: [:usuario_id, :rol_id])
    .insert(tenant_id: tenant_id, usuario_id: soporte_id, rol_id: soporte_rol)

  puts "✅ Usuarios: vendedor/vendedor, soporte/soporte"

  # ============================================================
  # CLIENTES
  # ============================================================
  clientes_data = [
    { tipo: "empresa", nombre: "Distribuidora del Este S.A.", documento: "80012345-6", email: "contacto@disteste.com.py", telefono: "021-123456", direccion: "Av. Mcal. López 1234, Asunción" },
    { tipo: "empresa", nombre: "Supermercado Central",        documento: "80023456-7", email: "info@supercentral.com.py",  telefono: "021-234567", direccion: "Palma 456, Asunción" },
    { tipo: "empresa", nombre: "Farmacia San Roque",          documento: "80034567-8", email: "ventas@sanroque.com.py",    telefono: "021-345678", direccion: "Mcal. Estigarribia 789, Asunción" },
    { tipo: "empresa", nombre: "Constructora Guaraní",        documento: "80045678-9", email: "obras@guarani.com.py",      telefono: "021-456789", direccion: "Eligio Ayala 101, Luque" },
    { tipo: "empresa", nombre: "Textil Paraguaya S.A.",       documento: "80056789-0", email: "info@textilpy.com.py",      telefono: "021-567890", direccion: "Ruta 2 Km 15, San Lorenzo" },
    { tipo: "persona", nombre: "Juan Ramón González",         documento: "1234567",    email: "jrgonzalez@gmail.com",      telefono: "0981-123456", direccion: "Barrio Villa Morra, Asunción" }
  ]

  cliente_ids = {}
  clientes_data.each do |c|
    cid = DB[:clientes].insert(
      tenant_id:  tenant_id,
      tipo:       c[:tipo],
      nombre:     c[:nombre],
      documento:  c[:documento],
      email:      c[:email],
      telefono:   c[:telefono],
      direccion:  c[:direccion],
      activo:     true,
      created_by: admin[:id]
    )
    cliente_ids[c[:nombre]] = cid
  end
  puts "✅ #{clientes_data.size} clientes"

  # ============================================================
  # CONTACTOS
  # ============================================================
  contactos_data = [
    { cliente: "Distribuidora del Este S.A.", nombre: "Pedro Fernández",  cargo: "Gerente de Compras",   email: "pedro@disteste.com.py", telefono: "0981-111111" },
    { cliente: "Distribuidora del Este S.A.", nombre: "Ana Ríos",          cargo: "Contadora",            email: "ana@disteste.com.py",   telefono: "0981-222222" },
    { cliente: "Supermercado Central",        nombre: "Luis Benítez",      cargo: "Encargado de Depósito",email: "luis@supercentral.com.py", telefono: "0981-333333" },
    { cliente: "Farmacia San Roque",          nombre: "Rosa Martínez",     cargo: "Dueña",                email: "rosa@sanroque.com.py",  telefono: "0981-444444" },
    { cliente: "Constructora Guaraní",        nombre: "Ing. Mario Aquino", cargo: "Jefe de Obras",        email: "mario@guarani.com.py",  telefono: "0981-555555" }
  ]

  contactos_data.each do |ct|
    DB[:contactos].insert(
      tenant_id:  tenant_id,
      cliente_id: cliente_ids[ct[:cliente]],
      nombre:     ct[:nombre],
      cargo:      ct[:cargo],
      email:      ct[:email],
      telefono:   ct[:telefono],
      activo:     true
    )
  end
  puts "✅ #{contactos_data.size} contactos"



  # ============================================================
  # ARTÍCULOS (catálogo de productos y servicios)
  # ============================================================
  articulos_data = [
    # --- PRODUCTOS (físicos, con stock) ---
    { codigo: "POS-001", nombre: "Sistema POS Básico",         tipo: "producto", precio: 1500000, descripcion: "Terminal POS + lector de código de barras + software básico" },
    { codigo: "POS-002", nombre: "Sistema POS Avanzado",        tipo: "producto", precio: 2800000, descripcion: "Terminal POS táctil + impresora térmica + lector + software completo" },
    { codigo: "IMP-001", nombre: "Impresora Térmica",           tipo: "producto", precio: 850000,  descripcion: "Impresora térmica 80mm para tickets" },
    { codigo: "LEC-001", nombre: "Lector de Código de Barras",  tipo: "producto", precio: 420000,  descripcion: "Lector USB 1D/2D" },
    { codigo: "CAJ-001", nombre: "Cajón de Dinero",             tipo: "producto", precio: 650000,  descripcion: "Cajón metálico con apertura automática" },
    { codigo: "TAB-001", nombre: "Tablet 10 pulgadas",          tipo: "producto", precio: 1950000, descripcion: "Tablet Android para punto de venta móvil" },

    # --- SERVICIOS (no tienen stock) ---
    { codigo: "INST-01", nombre: "Instalación en sitio",        tipo: "servicio", precio: 500000,  descripcion: "Instalación y configuración en las oficinas del cliente" },
    { codigo: "CAP-01",  nombre: "Capacitación de personal",    tipo: "servicio", precio: 350000,  descripcion: "Capacitación presencial de hasta 5 usuarios (4 horas)" },
    { codigo: "SOP-MEN", nombre: "Soporte mensual",             tipo: "servicio", precio: 250000,  descripcion: "Soporte técnico remoto ilimitado por 30 días" },
    { codigo: "MANT-01", nombre: "Mantenimiento anual",         tipo: "servicio", precio: 1800000, descripcion: "Mantenimiento preventivo y correctivo durante 12 meses" },
    { codigo: "CONS-01", nombre: "Consultoría en procesos",     tipo: "servicio", precio: 800000,  descripcion: "Consultoría para optimización de procesos comerciales (8 horas)" },
    { codigo: "TRAIN-01", nombre: "Entrenamiento avanzado",     tipo: "servicio", precio: 550000,  descripcion: "Entrenamiento avanzado para administradores" }
  ]

  articulos_data.each do |art|
    DB[:articulos].insert(
      tenant_id:   tenant_id,
      codigo:      art[:codigo],
      nombre:      art[:nombre],
      descripcion: art[:descripcion],
      precio:      art[:precio],
      tipo:        art[:tipo],
      activo:      true
    )
  end
  puts "✅ #{articulos_data.size} artículos (6 productos + 6 servicios)"





  # ============================================================
  # LEADS
  # ============================================================
  leads_data = [
    { nombre: "Roberto Silva",   empresa: "Silva Import",         origen: "web",       estado: "nuevo",       email: "rsilva@silvaimport.com", telefono: "0981-666666" },
    { nombre: "Patricia Núñez",  empresa: "Núñez Logística",      origen: "referido",  estado: "nuevo",       email: "pnunez@nunezlog.com",    telefono: "0981-777777" },
    { nombre: "Hugo Cáceres",    empresa: "Cáceres & Asociados",  origen: "llamada",   estado: "contactado",  email: "hcaceres@caceres.com",   telefono: "0981-888888" },
    { nombre: "Silvia Villalba", empresa: "Villalba Textil",      origen: "whatsapp",  estado: "contactado",  email: "svillalba@vtextil.com",  telefono: "0981-999999" },
    { nombre: "Diego Ocampo",    empresa: "Ocampo Refrigeración", origen: "web",       estado: "calificado",  email: "docampo@ocampo.com",     telefono: "0981-101010" },
    { nombre: "Carla Aguilera",  empresa: nil,                    origen: "referido",  estado: "descartado",  email: "carla.aguilera@gmail.com", telefono: "0981-202020" }
  ]

  lead_ids = {}
  leads_data.each do |l|
    lid = DB[:leads].insert(
      tenant_id:      tenant_id,
      nombre:         l[:nombre],
      empresa:        l[:empresa],
      email:          l[:email],
      telefono:       l[:telefono],
      origen:         l[:origen],
      estado:         l[:estado],
      responsable_id: vendedor_id,
      activo:         true
    )
    lead_ids[l[:nombre]] = lid
  end
  puts "✅ #{leads_data.size} leads"

  # ============================================================
  # OPORTUNIDADES
  # ============================================================
  hoy = Date.today

  oportunidades_data = [
    { titulo: "Venta de sistema POS a Distribuidora",       cliente: "Distribuidora del Este S.A.", etapa: "Contacto inicial", monto: 15000, fecha: hoy + 30 },
    { titulo: "Implementación en Supermercado Central",     cliente: "Supermercado Central",        etapa: "Contacto inicial", monto: 22000, fecha: hoy + 45 },
    { titulo: "Licencias para Farmacia San Roque",          cliente: "Farmacia San Roque",          etapa: "Contacto inicial", monto: 3500,  fecha: hoy + 20 },

    { titulo: "Capacitación a Constructora Guaraní",        cliente: "Constructora Guaraní",        etapa: "Calificación",     monto: 8000,  fecha: hoy + 25 },
    { titulo: "Renovación Textil Paraguaya",                cliente: "Textil Paraguaya S.A.",       etapa: "Calificación",     monto: 12000, fecha: hoy + 40 },

    { titulo: "Propuesta a Supermercado Central",           cliente: "Supermercado Central",        etapa: "Propuesta",        monto: 18000, fecha: hoy + 15 },
    { titulo: "Sistema completo para Distribuidora",        cliente: "Distribuidora del Este S.A.", etapa: "Propuesta",        monto: 35000, fecha: hoy + 30 },

    { titulo: "Contrato anual Farm. San Roque",             cliente: "Farmacia San Roque",          etapa: "Negociación",      monto: 9500,  fecha: hoy + 10 },
    { titulo: "Ampliación Textil Paraguaya",                cliente: "Textil Paraguaya S.A.",       etapa: "Negociación",      monto: 20000, fecha: hoy + 20 },

    { titulo: "Primer módulo Constructora Guaraní",         cliente: "Constructora Guaraní",        etapa: "Ganada",           monto: 6500,  fecha: hoy - 5  },

    { titulo: "Proyecto descartado - Juan González",        cliente: "Juan Ramón González",         etapa: "Perdida",          monto: 2000,  fecha: hoy - 10 }
  ]

  oportunidades_data.each do |op|
    DB[:oportunidades].insert(
      tenant_id:             tenant_id,
      titulo:                op[:titulo],
      cliente_id:            cliente_ids[op[:cliente]],
      etapa_id:              etapa_id.(op[:etapa]),
      monto_estimado:        op[:monto],
      fecha_cierre_estimada: op[:fecha],
      estado:                (op[:etapa] == "Ganada") ? "ganada" : (op[:etapa] == "Perdida") ? "perdida" : "abierta",
      responsable_id:        vendedor_id
    )
  end
  puts "✅ #{oportunidades_data.size} oportunidades"

  # ============================================================
  # ACTIVIDADES
  # ============================================================
  # Necesitamos los IDs de las oportunidades para vincular algunas
  oportunidad_ids = {}
  DB[:oportunidades].where(tenant_id: tenant_id).each do |o|
    oportunidad_ids[o[:titulo]] = o[:id]
  end

  hoy_dt = Time.now

  actividades_data = [
    # --- LLAMADAS (pasadas, completadas) ---
    {
      tipo: "llamada", titulo: "Llamada inicial a Pedro Fernández",
      descripcion: "Primer contacto. Interesado en cotización de sistema POS.",
      entidad: ["cliente", cliente_ids["Distribuidora del Este S.A."]],
      fecha: hoy_dt - 15*86400, completada: true
    },
    {
      tipo: "llamada", titulo: "Seguimiento a Luis Benítez",
      descripcion: "Confirmó interés. Pidió enviar propuesta por email.",
      entidad: ["cliente", cliente_ids["Supermercado Central"]],
      fecha: hoy_dt - 10*86400, completada: true
    },
    {
      tipo: "llamada", titulo: "Llamada de calificación a Hugo Cáceres",
      descripcion: "Calificado como cliente potencial serio. Pasar a etapa Propuesta.",
      entidad: ["lead", lead_ids["Hugo Cáceres"]],
      fecha: hoy_dt - 5*86400, completada: true
    },

    # --- EMAILS (pasados, completados) ---
    {
      tipo: "email", titulo: "Envío de propuesta a Supermercado Central",
      descripcion: "Propuesta enviada por email. Incluye 3 opciones de plan.",
      entidad: ["oportunidad", oportunidad_ids["Propuesta a Supermercado Central"]],
      fecha: hoy_dt - 7*86400, completada: true
    },
    {
      tipo: "email", titulo: "Follow-up a Rosa Martínez",
      descripcion: "Recordatorio de propuesta enviada hace 5 días.",
      entidad: ["cliente", cliente_ids["Farmacia San Roque"]],
      fecha: hoy_dt - 2*86400, completada: true
    },
    {
      tipo: "email", titulo: "Respuesta a consulta de Patricia Núñez",
      descripcion: "Responder consulta sobre precios y plazos de entrega.",
      entidad: ["lead", lead_ids["Patricia Núñez"]],
      fecha: hoy_dt + 1*86400, completada: false
    },

    # --- REUNIONES (mixtas) ---
    {
      tipo: "reunion", titulo: "Reunión en oficinas de Distribuidora",
      descripcion: "Reunión presencial con Pedro y Ana. Revisión del sistema completo.",
      entidad: ["cliente", cliente_ids["Distribuidora del Este S.A."]],
      fecha: hoy_dt - 3*86400, completada: true
    },
    {
      tipo: "reunion", titulo: "Demo online para Constructora Guaraní",
      descripcion: "Mostrar funcionalidades del sistema. Coordinar con Mario Aquino.",
      entidad: ["oportunidad", oportunidad_ids["Capacitación a Constructora Guaraní"]],
      fecha: hoy_dt + 3*86400, completada: false
    },
    {
      tipo: "reunion", titulo: "Reunión de cierre con Textil Paraguaya",
      descripcion: "Discutir condiciones finales del contrato de ampliación.",
      entidad: ["oportunidad", oportunidad_ids["Ampliación Textil Paraguaya"]],
      fecha: hoy_dt + 5*86400, completada: false
    },

    # --- NOTAS (contexto, sin fecha) ---
    {
      tipo: "nota", titulo: "Precio especial para cliente frecuente",
      descripcion: "Distribuidora pidió 15% de descuento por volumen. Consultar con gerencia.",
      entidad: ["cliente", cliente_ids["Distribuidora del Este S.A."]],
      fecha: nil, completada: true
    },
    {
      tipo: "nota", titulo: "Competencia: SoftPY está ofertando",
      descripcion: "Supermercado Central mencionó que SoftPY les hizo una oferta. Diferenciar con soporte 24/7.",
      entidad: ["oportunidad", oportunidad_ids["Implementación en Supermercado Central"]],
      fecha: nil, completada: true
    },

    # --- TAREAS (pendientes) ---
    {
      tipo: "tarea", titulo: "Preparar contrato para Constructora Guaraní",
      descripcion: "Armar borrador de contrato del primer módulo. Revisar con legales.",
      entidad: ["oportunidad", oportunidad_ids["Primer módulo Constructora Guaraní"]],
      fecha: hoy_dt + 2*86400, completada: false
    },
    {
      tipo: "tarea", titulo: "Enviar factura a Supermercado Central",
      descripcion: "Emitir factura por el primer pago acordado.",
      entidad: ["cliente", cliente_ids["Supermercado Central"]],
      fecha: hoy_dt + 4*86400, completada: false
    },
    {
      tipo: "tarea", titulo: "Actualizar datos de contacto de Diego Ocampo",
      descripcion: "Verificar email y teléfono. Nos rebotó el último email.",
      entidad: ["lead", lead_ids["Diego Ocampo"]],
      fecha: hoy_dt + 1*86400, completada: false
    },
    {
      tipo: "tarea", titulo: "Revisar condiciones de contrato Textil Paraguaya",
      descripcion: "Leer cláusulas del contrato de renovación antes de la reunión.",
      entidad: ["oportunidad", oportunidad_ids["Renovación Textil Paraguaya"]],
      fecha: hoy_dt - 1*86400, completada: false  # ← vencida a propósito
    },
    {
      tipo: "tarea", titulo: "Preparar presentación de reporte mensual",
      descripcion: "Armar PDF con métricas del mes para reunión interna.",
      entidad: [nil, nil],
      fecha: hoy_dt + 7*86400, completada: false
    },
    {
      tipo: "tarea", titulo: "Llamar a Juan Ramón González",
      descripcion: "Proyecto descartado. Mantener contacto para futuras oportunidades.",
      entidad: ["cliente", cliente_ids["Juan Ramón González"]],
      fecha: hoy_dt + 10*86400, completada: false
    },

    # --- TAREAS COMPLETADAS ---
    {
      tipo: "tarea", titulo: "Enviar catálogo de productos a Farmacia San Roque",
      descripcion: "Catálogo actualizado enviado por WhatsApp.",
      entidad: ["cliente", cliente_ids["Farmacia San Roque"]],
      fecha: hoy_dt - 6*86400, completada: true
    },
    {
      tipo: "tarea", titulo: "Confirmar datos para facturación",
      descripcion: "Confirmado RUC y razón social de Constructora Guaraní.",
      entidad: ["cliente", cliente_ids["Constructora Guaraní"]],
      fecha: hoy_dt - 4*86400, completada: true
    }
  ]

  actividades_data.each do |act|
    entidad_tipo, entidad_id = act[:entidad]

    DB[:actividades].insert(
      tenant_id:     tenant_id,
      tipo:          act[:tipo],
      titulo:        act[:titulo],
      descripcion:   act[:descripcion],
      entidad_tipo:  entidad_tipo,
      entidad_id:    entidad_id,
      fecha:         act[:fecha],
      completada:    act[:completada],
      completada_at: act[:completada] ? act[:fecha] : nil,
      usuario_id:    vendedor_id
    )
  end
  puts "✅ #{actividades_data.size} actividades (llamadas, emails, reuniones, notas, tareas)"
end

puts
puts "=========================================="
puts "Demo cargada en '#{codigo}'"
puts "=========================================="
puts "Login admin:    #{codigo}/login  →  admin / admin"
puts "Login vendedor: #{codigo}/login  →  vendedor / vendedor"
puts "Login soporte:  #{codigo}/login  →  soporte / soporte"
puts
puts "Demo incluye:"
puts "  - 2 usuarios (vendedor, soporte)"
puts "  - 6 clientes"
puts "  - 5 contactos"
puts "  - 6 leads"
puts "  - 11 oportunidades en pipeline"
puts "  - 19 actividades (3 llamadas, 3 emails, 3 reuniones, 2 notas, 8 tareas)"
puts "=========================================="