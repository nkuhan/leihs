class Admin::ItemsController < Admin::AdminController
  
  before_filter :pre_load
  
  def index
    case params[:filter]
      when "incompletes"
        items = Item.incompletes
      else
        items = Item
    end
    
    unless params[:query].blank?
      @items = items.find_by_contents("*" + params[:query] + "*",  :page => params[:page], :per_page => $per_page)
    else
      @items = items.paginate :page => params[:page], :per_page => $per_page 
    end
  end

  def show
    # template has to be .rhtml (??)
    @item.step = 'step_item'
  end

  def new
    show and render :action => 'show'
  end

  def create
    update
  end
      
  def update
    @item.step = params[:item][:step]
    if @item.update_attributes(params[:item])
      redirect_to admin_item_path(@item)
    else
      show and render :action => 'show' # TODO 24** redirect to the correct tabbed form
    end
  end

#################################################################

  def model
    @item.step = 'step_model'
  end

#################################################################

  def inventory_pool
    # forcing wizard step
    redirect_to admin_item_path(@item) unless @item.model
  end
  
  def set_inventory_pool
    ip = InventoryPool.find(params[:inventory_pool_id])
    @item.location = ip.main_location
    
    # if it's the first item of that model assigned to the inventory_pool,
    # then creates accessory associations
    @item.model.accessories.each {|a| ip.accessories << a } unless ip.models.include?(@item.model)
    # TODO *17* fix problem with accessories setting inventory_pool
    
    
    @item.step = 'step_location'
    @item.save
    redirect_to :action => 'inventory_pool', :id => @item
  end

#################################################################

  def status
    #render :layout => false
  end

#################################################################

  private
  
  def pre_load
    params[:id] ||= params[:item_id] if params[:item_id]
    @item = Item.find(params[:id]) if params[:id]
    @item ||= Item.new
  end

end
