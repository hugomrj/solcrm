# config.ru
require_relative "app"
require "rack/session/cookie"

use Rack::Session::Cookie,
  key:          "rack.session",
  secret:       ENV.fetch("SESSION_SECRET"),
  same_site:    :lax,
  httponly:     true,
  expire_after: 60 * 60 * 24 * 14

run SolCRM