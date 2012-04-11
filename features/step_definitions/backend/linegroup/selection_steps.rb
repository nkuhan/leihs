When /^I open a take back, hand over or I edit an order$/ do
  @ip = @user.managed_inventory_pools.first
  possible_types = ["take_back", "hand_over", "order"]
  type = possible_types.shuffle.first
  case type
    when "take_back"
      @customer = @ip.users.all.select {|x| x.contracts.signed.size > 0}.first
      @entity = @customer.contracts.signed.first
      visit backend_inventory_pool_user_take_back_path(@ip, @customer)
    when "hand_over"
      @customer = @ip.users.all.select {|x| x.contracts.unsigned.size > 0}.first
      @entity = @customer.contracts.unsigned.first
      visit backend_inventory_pool_user_hand_over_path(@ip, @customer)
    when "order"
      @customer = @ip.users.all.select {|x| x.orders.submitted.size > 0}.first
      @entity = @customer.orders.submitted.first
      visit backend_inventory_pool_acknowledge_path(@ip, @entity)
  end
end

When /^I select all lines of an linegroup$/ do
  @linegroup = find(".linegroup")
  @linegroup.all(".line").each do |line|
    line.find("input[type=checkbox]").click
  end
end

Then /^the linegroup is selected$/ do
  @linegroup.find("#select_group").checked?.should == true
end

Then /^the count matches the amount of selected lines$/ do
  count = find("#selection_actions .count").text.gsub(/[()]/, "").to_i
  all_lines = all(".line")
  lines_selected = all_lines.delete_if {|x| not x.find(".select input").checked?}
  lines_selected.size.should == count
end

When /^I select the linegroup$/ do
  @linegroup = find(".linegroup")
  @linegroup.find(".dates label").click
end

Then /^all lines of that linegroup are selected$/ do
  @linegroup.all(".line").each do |line|
    line.find(".select input[type=checkbox]").checked?.should == true
  end
end