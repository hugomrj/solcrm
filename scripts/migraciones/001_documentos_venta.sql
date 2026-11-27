-- ============================================================
-- 001 — Propuestas y presupuestos (Sprint 8)
-- ============================================================
-- Una sola tabla con `tipo` (propuesta | presupuesto) porque comparten
-- estructura y ciclo de vida.
-- Idempotente: se puede correr sobre una base donde ya existan.

CREATE TABLE IF NOT EXISTS documentos_venta (
    id          BIGSERIAL PRIMARY KEY,
    tenant_id   BIGINT       NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tipo        VARCHAR(20)  NOT NULL,
    numero      VARCHAR(50)  NOT NULL,
    cliente_id  BIGINT       REFERENCES clientes(id),
    fecha       DATE         NOT NULL DEFAULT CURRENT_DATE,
    validez     DATE,
    subtotal    NUMERIC(15,2) NOT NULL DEFAULT 0,
    impuestos   NUMERIC(15,2) NOT NULL DEFAULT 0,
    total       NUMERIC(15,2) NOT NULL DEFAULT 0,
    estado      VARCHAR(20)  NOT NULL DEFAULT 'borrador',
    notas       TEXT,
    factura_id  BIGINT       REFERENCES facturas(id),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, tipo, numero)
);

CREATE INDEX IF NOT EXISTS idx_docs_venta_tenant
    ON documentos_venta(tenant_id, tipo, estado);

CREATE TABLE IF NOT EXISTS documentos_venta_items (
    id                 BIGSERIAL PRIMARY KEY,
    documento_venta_id BIGINT        NOT NULL REFERENCES documentos_venta(id) ON DELETE CASCADE,
    articulo_id        BIGINT        REFERENCES articulos(id),
    descripcion        VARCHAR(255)  NOT NULL,
    cantidad           NUMERIC(10,2) NOT NULL DEFAULT 1,
    precio             NUMERIC(15,2) NOT NULL DEFAULT 0,
    total              NUMERIC(15,2) NOT NULL DEFAULT 0
);
