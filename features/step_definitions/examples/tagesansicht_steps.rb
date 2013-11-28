# encoding: utf-8

Angenommen(/^eine Bestellungen mit zwei unterschiedlichen Zeitspannen existiert$/) do
  @customer = @current_inventory_pool.users.customers.sample
  @contract = FactoryGirl.create :contract, user_id: @customer.id, status: 'submitted', inventory_pool_id: @current_inventory_pool.id
  FactoryGirl.create :contract_line, contract_id: @contract.id, start_date: Date.today, end_date: Date.tomorrow 
  FactoryGirl.create :contract_line, contract_id: @contract.id, start_date: Date.today, end_date: Date.today+10.days 
end

Dann(/^sehe ich für diese Bestellung die längste Zeitspanne direkt auf der Linie$/) do
  visit manage_daily_view_path(@current_inventory_pool)
  line_with_max_range = @contract.item_lines.max{|line| line.end_date - line.start_date}
  range = (line_with_max_range.end_date-line_with_max_range.start_date).to_i+1
  find(".line[data-id='#{@contract.id}']").should have_content "#{range} #{_('days')}"
end