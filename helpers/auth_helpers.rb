helpers do
    def current_user_name
      "Administrador"
    end
  
    def current_page?(page_name)
      @current_page == page_name ? 'active' : ''
    end
end