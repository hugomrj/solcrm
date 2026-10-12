require "sequel"
require "dotenv/load"

DB = Sequel.connect(
  adapter:  "postgres",
  host:     ENV.fetch("DB_HOST"),
  port:     ENV.fetch("DB_PORT"),
  database: ENV.fetch("DB_NAME"),
  user:     ENV.fetch("DB_USER"),
  password: ENV.fetch("DB_PASSWORD")
)

DB.extension :pagination   