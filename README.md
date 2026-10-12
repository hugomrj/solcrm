# SolCRM

CRM desarrollado con Ruby y Sinatra.

## Ejecutar

```bash
bundle install
bundle exec ruby app.rb
```

Abrir:

```text
http://localhost:4567
```


# SolCRM

CRM multi-tenant desarrollado con Ruby + Sinatra + PostgreSQL.

## Requisitos

- Ruby 3.2+
- PostgreSQL 14+
- Bundler

## Instalación

```bash
git clone <repo>
cd solcrm
bundle install
```

Configuración
1. Crear el archivo .env
En la raíz del proyecto, creá un archivo llamado .env con este contenido:

env
```
# Base de datos
DB_HOST=localhost
DB_PORT=5432
DB_NAME=solcrm_dev
DB_USER=tu_usuario
DB_PASSWORD=tu_password

# Sesiones (obligatorio)
SESSION_SECRET=pegá-acá-un-hex-de-64-chars

# Super admin
SUPER_ADMIN_USER=admin
SUPER_ADMIN_PASSWORD=cambiar123
SUPER_ADMIN_EMAIL=admin@solcrm.local
```

Es obligatorio. Sin .env la app no arranca.

Generá el SESSION_SECRET con:

bash 
```
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```


### Ejecutar

bash 
```
bundle exec rackup
```