require "bcrypt"
require_relative "db"

module Tenants
  ETAPAS_DEFAULT = [
    { nombre: "Contacto inicial", orden: 1, probabilidad: 10  },
    { nombre: "Calificación",     orden: 2, probabilidad: 25  },
    { nombre: "Propuesta",        orden: 3, probabilidad: 50  },
    { nombre: "Negociación",      orden: 4, probabilidad: 75  },
    { nombre: "Ganada",           orden: 5, probabilidad: 100 },
    { nombre: "Perdida",          orden: 6, probabilidad: 0   }
  ].freeze

  # Crea un tenant completo:
  #   - tenant
  #   - 6 etapas de pipeline
  #   - usuario admin
  #   - rol admin asignado
  #
  #   Tenants.crear("acme", "admin", "admin")
  def self.crear(codigo, usuario, password)
    DB.transaction do
      tenant_id  = insertar_tenant(codigo)
      insertar_etapas(tenant_id)
      usuario_id = insertar_usuario(tenant_id, codigo, usuario, password)
      asignar_rol_admin(tenant_id, usuario_id)

      { tenant_id: tenant_id, usuario_id: usuario_id }
    end
  end

  def self.insertar_tenant(codigo)
    DB[:tenants]
      .insert_conflict(
        target: :codigo,
        update: { nombre: Sequel[:excluded][:nombre] }
      )
      .returning(:id)
      .insert(codigo: codigo, nombre: codigo.capitalize)
      .first[:id]
  end

  def self.insertar_etapas(tenant_id)
    ETAPAS_DEFAULT.each do |etapa|
      DB[:pipeline_etapas]
        .insert_conflict(target: [:tenant_id, :nombre])
        .insert(
          tenant_id:    tenant_id,
          nombre:       etapa[:nombre],
          orden:        etapa[:orden],
          probabilidad: etapa[:probabilidad],
          activo:       true
        )
    end
  end

  def self.insertar_usuario(tenant_id, codigo, usuario, password)
    DB[:usuarios]
      .insert_conflict(
        target: [:tenant_id, :usuario],
        update: { password_hash: Sequel[:excluded][:password_hash] }
      )
      .returning(:id)
      .insert(
        tenant_id:     tenant_id,
        usuario:       usuario,
        email:         "#{usuario}@#{codigo}.local",
        password_hash: BCrypt::Password.create(password),
        nombre:        "Admin"
      )
      .first[:id]
  end

  def self.asignar_rol_admin(tenant_id, usuario_id)
    admin_rol_id = DB[:roles].where(nombre: "admin").get(:id)

    DB[:usuarios_roles]
      .insert_conflict(target: [:usuario_id, :rol_id])
      .insert(
        tenant_id:  tenant_id,
        usuario_id: usuario_id,
        rol_id:     admin_rol_id
      )
  end
end