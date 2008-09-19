class Template < ModelGroup

  acts_as_ferret :fields => [ :name ], :store_class_name => true

  # TODO merge model_links with same models and sum quantities

  # TODO pass inventory_pool_id
  def add_to_document(document, user_id, quantity = 1, start_date = nil, end_date = nil, inventory_pool = nil)
    model_links.each do |ml|
      document.add_line(ml.quantity, ml.model, user_id, start_date, end_date)
    end
  end  

  def total_quantity
    model_links.collect(&:quantity).sum
  end
  
  
end
