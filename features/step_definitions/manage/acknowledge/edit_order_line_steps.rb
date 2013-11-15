# -*- encoding : utf-8 -*-

When /^I open a contract for acknowledgement$/ do
  @ip = @current_user.managed_inventory_pools.first
  @customer = @ip.users.all.detect {|x| x.contracts.submitted.exists? }
  @contract = @customer.contracts.submitted.first
  visit manage_edit_contract_path(@ip, @contract)
  page.should have_selector("[data-order-approve]", :visible => true)
end

When /^I open a contract for acknowledgement with more then one line$/ do
  @ip = @current_user.managed_inventory_pools.first
  @customer = @ip.users.all.detect {|x| x.contracts.submitted.exists? and x.contracts.submitted.first.lines.size > 1}
  @contract = @customer.contracts.submitted.first
  visit manage_edit_contract_path(@ip, @contract)
  page.should have_selector("[data-order-approve]", :visible => true)
end

When /^I open the booking calendar for this line$/ do
  @line_element.find("[data-edit-lines]", :text => _("Change entry")).click
  step "I see the booking calendar"
end

When /^I edit the timerange of the selection$/ do
  if page.has_selector?(".button.green[data-hand-over-selection]") or page.has_selector?(".button.green[data-take-back-selection]")
    step 'ich editiere alle Linien'
  else
    find(".multibutton [data-selection-enabled][data-edit-lines='selected-lines']", :text => _("Edit Selection")).click
  end
  step "I see the booking calendar"
end

When /^I save the booking calendar$/ do
  find("#submit-booking-calendar", :text => _("Save")).click
  sleep(0.88)
  step "ensure there are no active requests"
  page.should_not have_selector(".modal")
end

When /^I change a contract lines time range$/ do
  @line = if @contract
    @contract.lines.sample
  else
    @customer.visits.hand_over.first.lines.sample
  end
  @line_element = all(".line[data-ids]").detect do |dom_line|
    JSON.parse(dom_line["data-ids"]).include? @line.id
  end
  @line_element ||= find(".line[data-id='#{@line.id}']")
  step 'I open the booking calendar for this line'
  @new_start_date = if @line.start_date + 1.day < Date.today
      Date.today
    else
      @line.start_date + 1.day
  end
  page.should have_selector(".fc-widget-content .fc-day-number")
  get_fullcalendar_day_element(@new_start_date).click
  find("#set-start-date", :text => _("Start Date")).click
  step 'I save the booking calendar'
end

Then /^the time range of that line is changed$/ do
  @line.reload.start_date.should == @new_start_date
end

When /^I change a contract lines quantity$/ do
  @line = if @contract
    @contract.lines.sample
  else
    @customer.visits.hand_over.first.lines.sample
  end
  @line_element = find(".line", match: :first, :text => @line.model.name)
  step 'I open the booking calendar for this line'
  @new_quantity = @line.model.total_borrowable_items_for_user @customer
  first("input#booking-calendar-quantity").set @new_quantity
  step 'I save the booking calendar'
end

Then /^the quantity of that line is changed$/ do
  @line_element = find(".line", match: :first, :text => @line.model.name)
  @line_element.find("div:nth-child(3) > span:nth-child(1)").text.should == @new_quantity.to_s
end

When /^I select two lines$/ do
  @line1 = @contract.lines.first
  @line1_element = find(".line", match: :first, :text => @line1.model.name)
  @line1_element.first("input[type=checkbox]").click
  @line2 = @contract.lines.second
  @line2_element = find(".line", match: :first, :text => @line2.model.name)
  @line2_element.first("input[type=checkbox]").click
end

When /^I change the time range for multiple lines$/ do
  step 'I select two lines'
  step 'I edit the timerange of the selection'
  @new_start_date = @line1.start_date + 2.days
  get_fullcalendar_day_element(@new_start_date).click
  find("#set-start-date", :text => _("Start Date")).click
  step 'I save the booking calendar'
end

Then /^the time range for that lines is changed$/ do
  @line1.reload.start_date.should == @line2.reload.start_date 
  @line1.reload.start_date.should == @new_start_date
end

When /^I close the booking calendar$/ do
  find(".modal .modal-header .modal-close", text: _("Cancel")).click
end

When /^I edit one of the selected lines$/ do
  all(".line").each do |line|
    if line.first("input").checked?
      @line_element = line
    end
  end
  step 'I open the booking calendar for this line'
end

Then /^I see the booking calendar$/ do
  page.should have_selector("#booking-calendar .fc-day-content")
end

When /^I change the time range for multiple lines that have quantity bigger then (\d+)$/ do |arg1|
  step 'I change a contract lines quantity'
  line_element = all(".line[data-ids]").detect do |dom_line|
    JSON.parse(dom_line["data-ids"]).include? @line.id
  end
  line_element.find("div:nth-child(3) > span:nth-child(1)").text.to_i.should == @new_quantity
  step 'I change the time range for multiple lines'
end

Then /^the quantity is not changed after just moving the lines start and end date$/ do
  line_element = all(".line[data-ids]").detect do |dom_line|
    JSON.parse(dom_line["data-ids"]).include? @line.id
  end
  line_element.find("div:nth-child(3) > span:nth-child(1)").text.to_i.should == @new_quantity
end