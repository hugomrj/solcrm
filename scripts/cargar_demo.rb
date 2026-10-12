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
end

puts
puts "=========================================="
puts "Demo cargada en '#{codigo}'"
puts "=========================================="
puts "Login admin:    #{codigo}/login  →  admin / admin"
puts "Login vendedor: #{codigo}/login  →  vendedor / vendedor"
puts "Login soporte:  #{codigo}/login  →  soporte / soporte"
puts "=========================================="