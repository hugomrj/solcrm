# modules/usuario/routes.rb

get "/login" do
    erb :"usuario/login", layout: false
end