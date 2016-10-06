#= require ../shared/upload_controller

class window.App.ItemAttachmentsController extends App.UploadController

  constructor: ->
    super
    @type = "attachment"
    @templatePath = "manage/views/models/form/attachment_inline_entry"
    @url = @item.url("upload/#{@type}")
    new App.InlineEntryRemoveController {el: @el}
