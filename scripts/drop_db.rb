require_relative "env_helper"

# scripts/drop_db.rb
#
#   bundle exec ruby scripts/drop_db.rb

database = ENV.fetch("DB_NAME")

puts "Borrando base de datos #{database}..."

conn = conectar_db(dbname: "postgres")

conn.exec(<<~SQL)
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE datname = '#{database}' AND pid <> pg_backend_pid();
SQL

conn.exec("DROP DATABASE IF EXISTS \"#{database}\"")
conn.close

puts "✅ Base de datos '#{database}' borrada."