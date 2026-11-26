# AGENTS.md — SolCRM

## Stack
Ruby + Sinatra (modular) + Sequel + PostgreSQL + ERB + BCrypt. Sin Rails.
Frontend: HTML + CSS custom (`public/css/styles.css`) + JS vanilla.
Iconos: Lucide (vía CDN, `<i data-lucide="..."></i>`).
Tema: claro/oscuro con toggle, anti-FOUC en `views/layout/base.erb`.

## Arquitectura
- Multi-tenant por slug en URL: `/<tenant>/<ruta>`. `BaseApp` reescribe `PATH_INFO`.
- `NON_TENANT`: `css, js, images, favicon.ico, super` → no pasan por resolución de tenant.
- Cada módulo en `modules/<area>/<modulo>/routes.rb`, subclase de `BaseApp`,
  registrado en `config/routes.rb` con `SolCRM.use`.
- Helpers:
  - `AuthHelpers`: `tenant`, `current_user`, `puede?`, `t`, `require_login`,
    `current_tenant_id`, `tenant_db`, `current_user_name`, `current_user_rol_principal`
  - `FlashHelpers`: `set_flash`, `render_flash`

## Super Admin
- Ruta raíz: `/super` (reservada en `NON_TENANT`, bypass de tenant).
- Módulo: `modules/super/admin/routes.rb` → clase `SuperAdminRoutes`.
- Usa `DB[:tabla]` directamente (NO `tenant_db`), porque opera entre tenants.
- Autenticación: flag `session[:is_super_admin]` o rol especial en BD.
- Usuario "Dios" creado por `scripts/crear_dios.rb` (tenant_id NULL o 0).
- Vistas en `views/super/admin/`.

## Reglas duras
1. NUNCA usar `DB[:tabla]` para datos de negocio → usar `tenant_db(:tabla)`.
2. Inserts de negocio SIEMPRE con `tenant_id: current_tenant_id`.
3. Links/form actions SIEMPRE con `t('/ruta')` (nunca "/ruta" hardcodeado).
4. Borrado = soft delete (`UPDATE activo:false, updated_at: ...`), nunca `DELETE`.
5. Cada módulo protegido con `before { require_login; halt 403 unless puede?(:x) }`
   y su entrada correspondiente en `_sidebar.erb`.
6. Vistas: setear `@current_page`, `@page_title`, `@filtros`. Form en `_form.erb`
   compartido por `nuevo.erb` y `editar.erb`.
7. Flash: `set_flash(:success/:error, msg)` + `redirect t(...)`.
8. Timestamps: en updates manuales, siempre incluir `updated_at: Sequel::CURRENT_TIMESTAMP`.
   Los inserts usan `created_at` si la tabla lo tiene.
9. Nombres de columnas: `snake_case` (ej: `fecha_cierre_estimada`, `tenant_id`).
10. Estados/categorías: definirlos como constantes `ESTADOS = %w[...]` en la clase de rutas.

## Base de datos
- **Fuente de verdad del schema:** `scripts/schema.sql`
- **Aplicar schema:** `ruby scripts/crear_estructura.rb`
- **Seeds:**
  - `crear_tenant.rb` → crea empresa de prueba
  - `crear_dios.rb` → crea super-admin (tenant_id NULL)
  - `cargar_demo.rb` → datos de ejemplo
- **Drop:** `ruby scripts/drop_db.rb`

### Reglas de diseño (OBLIGATORIAS)
1. **Toda tabla de negocio** DEBE tener `tenant_id INTEGER NOT NULL`.
2. **Índices únicos** son SIEMPRE compuestos con `tenant_id`:
   - ✅ `UNIQUE(tenant_id, documento)` en `clientes`
   - ✅ `UNIQUE(tenant_id, usuario)` en `usuarios`
   - ❌ NUNCA `UNIQUE(documento)` o `UNIQUE(email)` global
3. **Índices de performance** también incluyen `tenant_id` al inicio:
   - `INDEX(tenant_id, estado, created_at)` para queries típicas
4. **Tablas globales** (sin tenant_id): solo `tenants`, `roles`, `permisos`.
5. **Timestamps:** `created_at` y `updated_at` en todas las tablas de negocio.
6. **Soft delete:** columna `activo BOOLEAN DEFAULT true`, nunca `DELETE`.

### Ejemplo de tabla nueva (plantilla)
```sql
CREATE TABLE oportunidades (
  id            SERIAL PRIMARY KEY,
  tenant_id     INTEGER NOT NULL REFERENCES tenants(id),
  titulo        TEXT NOT NULL,
  estado        TEXT NOT NULL DEFAULT 'abierta',
  monto         NUMERIC(12,2),
  activo        BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, titulo)
);
CREATE INDEX idx_oportunidades_tenant_estado
  ON oportunidades(tenant_id, estado);
```

## Patrón de módulo CRUD (6 endpoints estándar)
```
GET    /<modulo>              → index.erb      (listado con paginación + filtros + búsqueda)
GET    /<modulo>/nuevo        → nuevo.erb      (form vacío)
POST   /<modulo>              → crear          (validar, insertar, flash, redirect)
GET    /<modulo>/:id/editar   → editar.erb     (form con @registro cargado)
POST   /<modulo>/:id          → actualizar     (validar, update, flash, redirect)
POST   /<modulo>/:id/eliminar → soft delete    (activo:false, flash, redirect)
```

## Patrón de listado (repetido en todos los módulos)
```ruby
page = (params[:page] || 1).to_i
page = 1 if page < 1
dataset = tenant_db(:tabla)

# Filtros por enum
dataset = dataset.where(campo: params[:campo]) if VALORES.include?(params[:campo])

# Búsqueda ILIKE
q = params[:q].to_s.strip
unless q.empty?
  patron = "%#{q}%"
  dataset = dataset.where(
    Sequel.ilike(:campo1, patron) | Sequel.ilike(:campo2, patron)
  )
end

@registros = dataset.order(:campo).paginate(page, 25)
@filtros   = { q: q, campo: params[:campo] }
erb :"area/modulo/index"
```

## Endpoints JSON (solo para AJAX)
Usar `content_type :json` + `.to_json` ÚNICAMENTE cuando el frontend necesita
actualizar la UI sin recargar. Casos actuales:
- `POST /actividades/:id/completar` → toggle de tarea
- `POST /pipeline/:id/mover` → drag & drop de oportunidades
NO crear endpoints JSON "por si acaso". Si la acción es un CRUD completo,
usar el patrón HTML + redirect + flash.

## Estructura de un módulo nuevo
1. `modules/<area>/<nombre>/routes.rb`
2. `views/<area>/<nombre>/{index,nuevo,editar,_form}.erb`
3. `require_relative` + `SolCRM.use` en `config/routes.rb`
4. Entrada en `views/layout/partials/_sidebar.erb` condicionada a `puede?(:permiso)`
5. Permiso nuevo en tabla `roles`/`permisos` si aplica
6. Icono Lucide coherente con el resto del sidebar

## Comandos
- `rackup` / `bundle exec rackup`
- `ruby scripts/crear_estructura.rb`
- `ruby scripts/crear_tenant.rb <codigo> <nombre>`
- `ruby scripts/crear_dios.rb`
- `ruby scripts/cargar_demo.rb`
- `ruby scripts/drop_db.rb`

## No hacer
- No introducir Rails, ActiveRecord ni romper la separación por módulos.
- No agregar gemas sin justificar (Sequel ya cubre ORM + paginación).
- No tocar el flujo de tenant en `app.rb` sin entender `NON_TENANT`.
- No hardcodear URLs como `"/clientes"` → siempre `t('/clientes')`.
- No hacer `DELETE FROM` → siempre soft delete.
- No mezclar `DB[:tabla]` con `tenant_db(:tabla)` en el mismo módulo de negocio.
- No crear endpoints JSON para CRUDs completos (usar el patrón HTML + redirect).
- No modificar `helpers/auth_helpers.rb` sin considerar el impacto en Super Admin.
- No crear `UNIQUE` globales en tablas de negocio → siempre compuestos con `tenant_id`.