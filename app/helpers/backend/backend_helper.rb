module Backend::BackendHelper
  
  def last_visitors
    #TODO: last visitors should be scoped through inventory_pool and later through selected day in daily view
    #TODO: move this inside of the inventory pools model ?
    return false if session[:last_visitors].blank?
    session[:last_visitors].reverse.map { |x| link_to x.second, backend_inventory_pool_search_path(current_inventory_pool, :term => x.second), :class => "clickable" }.join()
  end
  
  def is_current_page?(section)
    
    def path_parameters?(h)
      r = request.env["action_dispatch.request.path_parameters"]
      h.all? do |k,v|
        r[k.to_sym] == v.to_s
      end
    end

    #TODO: PREVENT LOOPING
    # return false if caller == is_current_page?(section)
    @cached_is_current_page ||= {}
    @cached_is_current_page[section] ||= case section
      when "lending"
        is_current_page?("daily") or
        is_current_page?("orders") or
        is_current_page?("hand_over") or
        is_current_page?("take_back") or
        is_current_page?("contracts") or
        is_current_page?("visits")
      when "daily"
        current_inventory_pool and path_parameters?(:controller => "backend/inventory_pools", :action => "show")
      when "orders"
        path_parameters?(:controller => "backend/orders") ||
        !!(request.path =~ /acknowledge\/\d+$/)
      when "search"
        path_parameters?(:controller => "backend/backend", :action => :search)
      when "focused_search"
        path_parameters?(:controller => "backend/backend", :action => :search) and params[:types] and params[:types].size == 1
      when "hand_over"
        path_parameters?(:controller => "backend/hand_over", :action => :show)
      when "take_back"
        path_parameters?(:controller => "backend/take_back", :action => :show)
      when "contracts"
        path_parameters?(:controller => "backend/contracts")
      when "visits"
        path_parameters?(:controller => "backend/visits") or
          is_current_page?("hand_over") or
            is_current_page?("take_back")
      when "admin"
        is_current_page?("inventory_pools")
      when "inventory_pools"
        path_parameters?(:controller => "backend/inventory_pools", :action => :index)
      when "inventory"
        is_current_page?("models") or
          is_current_page?("items")
      when "models"
        path_parameters?(:controller => "backend/models")
      when "items"
        path_parameters?(:controller => "backend/items", :action => :show) or
        path_parameters?(:controller => "backend/items", :action => :update)
      when "current_user"
        path_parameters?(:controller => "backend/users", :action => :show) and @user == current_user
      when "start_screen"
        current_user.start_screen == request.fullpath
    end
    
    # We rescue everything because backend/hand_over and backend/take_back are failing sometimes
    rescue
      false
    
  end

end