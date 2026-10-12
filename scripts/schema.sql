-- ============================================================
-- SolCRM — Schema completo multi-tenant
-- ============================================================
-- Reset:
--   bundle exec ruby scripts/drop_db.rb
--   bundle exec ruby scripts/crear_estructura.rb
-- ============================================================

-- ============================================================
-- DROP
-- ============================================================
DROP TABLE IF EXISTS tickets_mensajes CASCADE;
DROP TABLE IF EXISTS tickets CASCADE;
DROP TABLE IF EXISTS archivos CASCADE;
DROP TABLE IF EXISTS suscripciones CASCADE;
DROP TABLE IF EXISTS gastos CASCADE;
DROP TABLE IF EXISTS proyectos CASCADE;
DROP TABLE IF EXISTS stock_movimientos CASCADE;
DROP TABLE IF EXISTS ordenes_compra_items CASCADE;
DROP TABLE IF EXISTS ordenes_compra CASCADE;
DROP TABLE IF EXISTS proveedores CASCADE;
DROP TABLE IF EXISTS notas_credito CASCADE;
DROP TABLE IF EXISTS pagos CASCADE;
DROP TABLE IF EXISTS facturas_items CASCADE;
DROP TABLE IF EXISTS facturas CASCADE;
DROP TABLE IF EXISTS articulos CASCADE;
DROP TABLE IF EXISTS actividades CASCADE;
DROP TABLE IF EXISTS oportunidades_historial CASCADE;
DROP TABLE IF EXISTS oportunidades CASCADE;
DROP TABLE IF EXISTS pipeline_etapas CASCADE;
DROP TABLE IF EXISTS leads CASCADE;
DROP TABLE IF EXISTS contactos CASCADE;
DROP TABLE IF EXISTS clientes CASCADE;
DROP TABLE IF EXISTS usuarios_roles CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;
DROP TABLE IF EXISTS super_admins CASCADE;

-- ============================================================
-- FASE 1 — BASE
-- ============================================================

CREATE TABLE super_admins (
    id            BIGSERIAL PRIMARY KEY,
    usuario       VARCHAR(50)  NOT NULL UNIQUE,
    email         VARCHAR(255),
    password_hash VARCHAR(255) NOT NULL,
    nombre        VARCHAR(255) NOT NULL,
    activo        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE tenants (
    id         BIGSERIAL PRIMARY KEY,
    codigo     VARCHAR(50)  NOT NULL UNIQUE,
    nombre     VARCHAR(255) NOT NULL,
    plan       VARCHAR(30)  NOT NULL DEFAULT 'basico',
    activo     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tenants_codigo ON tenants(codigo) WHERE activo = TRUE;

CREATE TABLE roles (
    id          BIGSERIAL PRIMARY KEY,
    nombre      VARCHAR(50)  NOT NULL UNIQUE,
    descripcion VARCHAR(255),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE usuarios (
    id            BIGSERIAL PRIMARY KEY,
    tenant_id     BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    usuario       VARCHAR(50)  NOT NULL,
    email         VARCHAR(255),
    password_hash VARCHAR(255) NOT NULL,
    nombre        VARCHAR(255) NOT NULL,
    activo        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, usuario)
);
CREATE INDEX idx_usuarios_tenant ON usuarios(tenant_id) WHERE activo = TRUE;

CREATE TABLE usuarios_roles (
    id         BIGSERIAL PRIMARY KEY,
    tenant_id  BIGINT      NOT NULL REFERENCES tenants(id)  ON DELETE CASCADE,
    usuario_id BIGINT      NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    rol_id     BIGINT      NOT NULL REFERENCES roles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (usuario_id, rol_id)
);
CREATE INDEX idx_usuarios_roles_usuario ON usuarios_roles(usuario_id);

-- ============================================================
-- FASE 2 — CRM
-- ============================================================

CREATE TABLE clientes (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tipo        VARCHAR(20)  NOT NULL DEFAULT 'empresa',
    nombre      VARCHAR(255) NOT NULL,
    documento   VARCHAR(50),
    email       VARCHAR(255),
    telefono    VARCHAR(50),
    direccion   VARCHAR(255),
    notas       TEXT,
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    created_by  BIGINT       REFERENCES usuarios(id),
    UNIQUE (tenant_id, documento)
);
CREATE INDEX idx_clientes_tenant ON clientes(tenant_id) WHERE activo = TRUE;
CREATE TABLE contactos (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    cliente_id  BIGINT       NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
    nombre      VARCHAR(255) NOT NULL,
    cargo       VARCHAR(150),
    email       VARCHAR(255),
    telefono    VARCHAR(50),
    notas       TEXT,
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_contactos_cliente ON contactos(cliente_id) WHERE activo = TRUE;

CREATE TABLE leads (
    id                      BIGSERIAL PRIMARY KEY,
    tenant_id               BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nombre                  VARCHAR(255) NOT NULL,
    empresa                 VARCHAR(255),
    email                   VARCHAR(255),
    telefono                VARCHAR(50),
    origen                  VARCHAR(50),
    estado                  VARCHAR(30)  NOT NULL DEFAULT 'nuevo',
    notas                   TEXT,
    responsable_id          BIGINT       REFERENCES usuarios(id),
    convertido_a_cliente_id BIGINT       REFERENCES clientes(id),
    activo                  BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_leads_tenant ON leads(tenant_id) WHERE activo = TRUE;

CREATE TABLE pipeline_etapas (
    id         BIGSERIAL PRIMARY KEY,
    tenant_id  BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nombre     VARCHAR(100) NOT NULL,
    orden      INTEGER      NOT NULL,
    activo     BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE oportunidades (
    id                    BIGSERIAL PRIMARY KEY,
    tenant_id             BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    titulo                VARCHAR(255) NOT NULL,
    cliente_id            BIGINT       REFERENCES clientes(id),
    lead_id               BIGINT       REFERENCES leads(id),
    etapa_id              BIGINT       REFERENCES pipeline_etapas(id),
    monto_estimado        NUMERIC(15,2),
    probabilidad          INTEGER,
    fecha_cierre_estimada DATE,
    fecha_cierre_real     DATE,
    estado                VARCHAR(20)  NOT NULL DEFAULT 'abierta',
    responsable_id        BIGINT       REFERENCES usuarios(id),
    notas                 TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_oportunidades_tenant ON oportunidades(tenant_id);

CREATE TABLE oportunidades_historial (
    id                BIGSERIAL PRIMARY KEY,
    tenant_id         BIGINT      NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    oportunidad_id    BIGINT      NOT NULL REFERENCES oportunidades(id) ON DELETE CASCADE,
    etapa_anterior_id BIGINT      REFERENCES pipeline_etapas(id),
    etapa_nueva_id    BIGINT      REFERENCES pipeline_etapas(id),
    usuario_id        BIGINT      REFERENCES usuarios(id),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE actividades (
    id            BIGSERIAL PRIMARY KEY,
    tenant_id     BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tipo          VARCHAR(20)  NOT NULL,
    titulo        VARCHAR(255) NOT NULL,
    descripcion   TEXT,
    entidad_tipo  VARCHAR(20),
    entidad_id    BIGINT,
    fecha         TIMESTAMPTZ,
    completada    BOOLEAN      NOT NULL DEFAULT FALSE,
    completada_at TIMESTAMPTZ,
    usuario_id    BIGINT       REFERENCES usuarios(id),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_actividades_entidad ON actividades(tenant_id, entidad_tipo, entidad_id);
CREATE INDEX idx_actividades_fecha ON actividades(tenant_id, fecha);

-- ============================================================
-- FASE 3 — VENTAS
-- ============================================================

CREATE TABLE articulos (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    codigo      VARCHAR(50),
    nombre      VARCHAR(255) NOT NULL,
    descripcion TEXT,
    precio      NUMERIC(15,2) NOT NULL DEFAULT 0,
    tipo        VARCHAR(20)  NOT NULL DEFAULT 'producto',
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, codigo)
);

CREATE TABLE facturas (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    numero      VARCHAR(50)  NOT NULL,
    cliente_id  BIGINT       NOT NULL REFERENCES clientes(id),
    fecha       DATE         NOT NULL DEFAULT CURRENT_DATE,
    vencimiento DATE,
    subtotal    NUMERIC(15,2) NOT NULL DEFAULT 0,
    impuestos   NUMERIC(15,2) NOT NULL DEFAULT 0,
    total       NUMERIC(15,2) NOT NULL DEFAULT 0,
    estado      VARCHAR(20)  NOT NULL DEFAULT 'borrador',
    notas       TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, numero)
);
CREATE INDEX idx_facturas_cliente ON facturas(cliente_id);

CREATE TABLE facturas_items (
    id          BIGSERIAL PRIMARY KEY,
    factura_id  BIGINT        NOT NULL REFERENCES facturas(id) ON DELETE CASCADE,
    articulo_id BIGINT        REFERENCES articulos(id),
    descripcion VARCHAR(255)  NOT NULL,
    cantidad    NUMERIC(10,2) NOT NULL DEFAULT 1,
    precio      NUMERIC(15,2) NOT NULL DEFAULT 0,
    total       NUMERIC(15,2) NOT NULL DEFAULT 0
);

CREATE TABLE pagos (
    id         BIGSERIAL PRIMARY KEY,
    tenant_id  BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    factura_id BIGINT       REFERENCES facturas(id),
    cliente_id BIGINT       NOT NULL REFERENCES clientes(id),
    fecha      DATE         NOT NULL DEFAULT CURRENT_DATE,
    monto      NUMERIC(15,2) NOT NULL,
    metodo     VARCHAR(30),
    referencia VARCHAR(100),
    notas      TEXT,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE notas_credito (
    id         BIGSERIAL PRIMARY KEY,
    tenant_id  BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    numero     VARCHAR(50)  NOT NULL,
    cliente_id BIGINT       NOT NULL REFERENCES clientes(id),
    factura_id BIGINT       REFERENCES facturas(id),
    fecha      DATE         NOT NULL DEFAULT CURRENT_DATE,
    monto      NUMERIC(15,2) NOT NULL,
    motivo     TEXT,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, numero)
);

-- ============================================================
-- FASE 4 — OPERACIONES
-- ============================================================

CREATE TABLE proveedores (
    id         BIGSERIAL PRIMARY KEY,
    tenant_id  BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nombre     VARCHAR(255) NOT NULL,
    documento  VARCHAR(50),
    email      VARCHAR(255),
    telefono   VARCHAR(50),
    direccion  VARCHAR(255),
    notas      TEXT,
    activo     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, documento)
);

CREATE TABLE ordenes_compra (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    numero       VARCHAR(50)  NOT NULL,
    proveedor_id BIGINT       NOT NULL REFERENCES proveedores(id),
    fecha        DATE         NOT NULL DEFAULT CURRENT_DATE,
    total        NUMERIC(15,2) NOT NULL DEFAULT 0,
    estado       VARCHAR(20)  NOT NULL DEFAULT 'borrador',
    notas        TEXT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, numero)
);

CREATE TABLE ordenes_compra_items (
    id              BIGSERIAL PRIMARY KEY,
    orden_compra_id BIGINT        NOT NULL REFERENCES ordenes_compra(id) ON DELETE CASCADE,
    articulo_id     BIGINT        REFERENCES articulos(id),
    descripcion     VARCHAR(255)  NOT NULL,
    cantidad        NUMERIC(10,2) NOT NULL DEFAULT 1,
    precio          NUMERIC(15,2) NOT NULL DEFAULT 0,
    total           NUMERIC(15,2) NOT NULL DEFAULT 0
);

CREATE TABLE stock_movimientos (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    articulo_id BIGINT        NOT NULL REFERENCES articulos(id),
    tipo        VARCHAR(20)   NOT NULL,
    cantidad    NUMERIC(10,2) NOT NULL,
    referencia  VARCHAR(100),
    motivo      TEXT,
    usuario_id  BIGINT        REFERENCES usuarios(id),
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_stock_articulo ON stock_movimientos(articulo_id);

CREATE TABLE proyectos (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nombre       VARCHAR(255) NOT NULL,
    cliente_id   BIGINT       REFERENCES clientes(id),
    estado       VARCHAR(20)  NOT NULL DEFAULT 'activo',
    fecha_inicio DATE,
    fecha_fin    DATE,
    presupuesto  NUMERIC(15,2),
    notas        TEXT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE gastos (
    id         BIGSERIAL PRIMARY KEY,
    tenant_id  BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    fecha      DATE         NOT NULL DEFAULT CURRENT_DATE,
    concepto   VARCHAR(255) NOT NULL,
    monto      NUMERIC(15,2) NOT NULL,
    categoria  VARCHAR(50),
    notas      TEXT,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_gastos_fecha ON gastos(tenant_id, fecha);

-- ============================================================
-- FASE 5 — SOPORTE
-- ============================================================

CREATE TABLE tickets (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    numero      VARCHAR(50)  NOT NULL,
    cliente_id  BIGINT       REFERENCES clientes(id),
    asunto      VARCHAR(255) NOT NULL,
    descripcion TEXT,
    estado      VARCHAR(20)  NOT NULL DEFAULT 'abierto',
    prioridad   VARCHAR(20)  NOT NULL DEFAULT 'normal',
    asignado_id BIGINT       REFERENCES usuarios(id),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, numero)
);
CREATE INDEX idx_tickets_estado ON tickets(tenant_id, estado);

CREATE TABLE tickets_mensajes (
    id         BIGSERIAL PRIMARY KEY,
    ticket_id  BIGINT      NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    usuario_id BIGINT      REFERENCES usuarios(id),
    mensaje    TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- FASE 6 — SUSCRIPCIONES
-- ============================================================

CREATE TABLE suscripciones (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    cliente_id   BIGINT       NOT NULL REFERENCES clientes(id),
    plan         VARCHAR(50)  NOT NULL,
    monto        NUMERIC(15,2) NOT NULL,
    periodicidad VARCHAR(20)  NOT NULL DEFAULT 'mensual',
    fecha_inicio DATE         NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin    DATE,
    estado       VARCHAR(20)  NOT NULL DEFAULT 'activa',
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- FASE 7 — ARCHIVOS
-- ============================================================

CREATE TABLE archivos (
    id           BIGSERIAL PRIMARY KEY,
    tenant_id    BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    nombre       VARCHAR(255) NOT NULL,
    path         VARCHAR(500) NOT NULL,
    tipo_mime    VARCHAR(100),
    tamano       BIGINT,
    entidad_tipo VARCHAR(20),
    entidad_id   BIGINT,
    usuario_id   BIGINT       REFERENCES usuarios(id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_archivos_entidad ON archivos(tenant_id, entidad_tipo, entidad_id);