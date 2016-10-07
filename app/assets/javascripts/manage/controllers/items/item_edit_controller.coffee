class window.App.ItemEditController extends App.FormWithUploadController

  elements:
    "#flexible-fields": "flexibleFields"
    "#form": "itemForm"
    "input[name='copy']": "copyInput"

  events: 
    "click #item-save-and-copy": "saveAndCopy"
    "click #show-all-fields": "showAllFields"
    "click [data-type='remove-field']": "removeField"

  constructor:->
    super
    @flexibleFieldsController = new App.ItemFlexibleFieldsController
      el: @flexibleFields
      itemData: @itemData
      itemType: @itemType
      writeable: true
      hideable: true
      callback: =>
        @attachmentsController = new App.ItemAttachmentsController {el: @el.find("#attachments"), item: @item}

  save: =>
    if @flexibleFieldsController.validate()
      $.ajax
        url: @item.url()
        data: @itemForm.serializeArray()
        type: "PUT"

  done: =>
    @attachmentsController.upload =>
      do @finish

  finish: =>
    if @attachmentsController.uploadErrors.length
      @setupErrorModal(@item)
    else
      window.location = App.Inventory.url()+"?flash[success]=#{_jed('Item saved')}"

  saveAndCopy: =>
    if @flexibleFieldsController.validate()
      @copyInput.prop "disabled", false
      @itemForm.submit()

  showAllFields: ->
    $.ajax
      url: "/manage/#{App.InventoryPool.current.id}/fields"
      type: "post"
      data:
        _method: "delete"
      success: (response) =>
        $(".hidden.field").removeClass("hidden")
        $("#show-all-fields").hide()

  removeField: (e)=>
    target = $(e.currentTarget).closest("[data-type='field']")
    $.ajax
      url: "/manage/#{App.InventoryPool.current.id}/fields/#{target.data("id")}"
      type: "post"
      success: (response) =>
        field = App.Field.find target.data("id")
        for child in field.children()
          target.closest("form").find("[name='#{child.getFormName()}']").closest("[data-type='field']").addClass("hidden")
        target.addClass("hidden")
        $("#show-all-fields").show()
