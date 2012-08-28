# encoding: utf-8

Angenommen /^ich editiere eine Bestellung$/ do
  @event = "order"
  step 'I open an order for acknowledgement'
end

Angenommen /^ich mache eine Rücknahme$/ do
  @event = "take_back"
  step 'I open a take back'
end

Angenommen /^ich mache eine Aushändigung$/ do
  @event = "hand_over"
  step 'I open a hand over'
end

Angenommen /^eine Model ist nichtmehr verfügbar$/ do
  if @event=="order" or @event=="hand_over"
    step 'I add so many lines that I break the maximal quantity of an model'
  else
    @model = @contract.models.first
    visit backend_inventory_pool_user_hand_over_path(@ip, @customer)
    step 'I add so many lines that I break the maximal quantity of an model'
    visit backend_inventory_pool_user_take_back_path(@ip, @customer)
  end
  @lines = all(".line.error", :text => @model.name)
  @lines.size.should > 0
end

Dann /^sehe ich auf den beteiligten Linien die Auszeichnung von Problemen$/ do
  @problems = []

  @lines.each do |line|
    page.execute_script(%Q{ $(".line[data-id=#{line["data-id"]}] .problems").trigger("mouseenter") })
    wait_until { find(".tip").text.match(/\d/) }
    @problems << find(".tip").text
  end
  @reference_line = @lines.first
  @reference_problem = @problems.first
  @line = if @event == "hand_over" or @event == "take_back"
    ContractLine.find @reference_line["data-id"]
  else
    OrderLine.find @reference_line["data-id"]
  end
  @av = @line.model.availability_in(@line.inventory_pool)
end

Dann /^das Problem wird wie folgt dargestellt: "(.*?)"$/ do |format|
  regexp = if (format == "Nicht verfügbar 2(3)/7")
     /(Nicht verfügbar|Not available): -*\d\(-*\d\)\/\d/
  elsif  format == "Gegenstand nicht ausleihbar"
    /(Gegenstand nicht ausleihbar|Item not borrowable)/
  elsif  format == "Gegenstand ist defekt"
    /(Gegenstand ist defekt|Item is defective)/
  elsif  format == "Gegenstand ist unvollständig"
    /(Gegenstand ist unvollständig|Item is incomplete)/
  elsif (format == "Verspätet seit 6 Tagen")
     /(Verspätet seit \d+ Tagen|Overdue since \d+ days)/
  end

  @problems.each do |problem|
    problem.match(regexp).should_not be_nil
  end
end

Dann /^"(.*?)" sind verfügbar für den Kunden$/ do |arg1|
  max = @av.maximum_available_in_period_summed_for_groups(@line.start_date, @line.end_date, @line.group_ids)
  max += @line.quantity if @event == "take_back"
  @reference_problem.match(/#{max}\(/).should_not be_nil
end

Dann /^"(.*?)" sind insgesamt verfügbar$/ do |arg1|
  max = @av.maximum_available_in_period_summed_for_groups(@line.start_date, @line.end_date, @ip.group_ids)
  max += @line.quantity if @event == "take_back"
  @reference_problem.match(/\(#{max}/).should_not be_nil
end

Dann /^"(.*?)" sind total im Pool bekannt \(ausleihbar\)$/ do |arg1|
  @reference_problem.match("/#{@line.model.items.scoped_by_inventory_pool_id(@line.inventory_pool).borrowable.size}").should_not be_nil
end

Angenommen /^eine Gegenstand ist nicht ausleihbar$/ do
  if @event == "hand_over"
    @item = @ip.items.unborrowable.first
    step 'I add an item to the hand over'
    @line = find(".line.assigned") 
  elsif @event === "take_back"
    @line = find(".item_line")
    step 'markiere ich den Gegenstand als nicht ausleihbar'
  end
end

Angenommen /^ich mache eine Rücknahme eines verspäteten Gegenstandes$/ do
  @event = "take_back"
  @ip = @user.managed_inventory_pools.first
  overdued_take_back = @ip.visits.take_back.detect{|x| x.date < Date.today}
  visit backend_inventory_pool_user_take_back_path(@ip, overdued_take_back.user)
  @line = find(".line[data-id='#{overdued_take_back.lines.first.id}']") 
end

Dann /^markiere ich den Gegenstand als nicht ausleihbar$/ do
  @line.find(".actions .trigger").click
  @line.find(".actions .button", :text => "Inspect").click
  wait_until { find(".dialog") }
  find("select[name='flags[is_borrowable]']").select "Nicht ausleihbar"
  find(".dialog .navigation button[type='submit']").click
  wait_until { find(".notification") }
end

Dann /^markiere ich den Gegenstand als defekt$/ do
  @line.find(".actions .trigger").click
  @line.find(".actions .button", :text => "Inspect").click
  wait_until { find(".dialog") }
  find("select[name='flags[is_broken]']").select "Defekt"
  find(".dialog .navigation button[type='submit']").click
  wait_until { find(".notification") }
end

Dann /^markiere ich den Gegenstand als unvollständig$/ do
  @line.find(".actions .trigger").click
  @line.find(".actions .button", :text => "Inspect").click
  wait_until { find(".dialog") }
  find("select[name='flags[is_incomplete]']").select "Unvollständig"
  find(".dialog .navigation button[type='submit']").click
  wait_until { find(".notification") }
end

Angenommen /^eine Gegenstand ist defekt$/ do
  if @event == "hand_over"
    @item = @ip.items.broken.first
    step 'I add an item to the hand over'
    @line = find(".line.assigned") 
  elsif  @event == "take_back"
    @line = find(".item_line")
    step 'markiere ich den Gegenstand als defekt'
  end
end

Angenommen /^eine Gegenstand ist unvollständig$/ do
  if @event == "hand_over"
    @item = @ip.items.incomplete.first
    step 'I add an item to the hand over'
    @line = find(".line.assigned") 
  elsif  @event == "take_back"
    @line = find(".item_line")
    step 'markiere ich den Gegenstand als unvollständig'
  end
end

Dann /^sehe ich auf der Linie des betroffenen Gegenstandes die Auszeichnung von Problemen$/ do
  wait_until { find(".line[data-id='#{@line.reload["data-id"]}']") }
  page.execute_script(%Q{ $(".line[data-id=#{@line.reload["data-id"]}] .problems").trigger("mouseenter") })
  wait_until { find(".tip").text.match(/\w/) }
  @problems = []
  @problems << find(".tip").text
end
