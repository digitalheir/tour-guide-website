# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

makeLoading = (e) ->
  $('#btn-go-container').html('<div class="loading"><div class="loading-wheel"/></div>')
  $('form').submit()
  false


closeDescription = ->
  $(this).removeClass('opened').addClass('closed').off('click').on('click', openDescription)
  $(this).parent().parent().find('.description').removeClass('opened').addClass('closed')

openDescription = ->
  console.log('click')
  $(this).removeClass('closed').addClass('opened').off('click').on('click', closeDescription)
  $(this).parent().parent().find('.description').removeClass('closed').addClass('opened')

initialize = ->
  #Welcome page
  $('#btn-go').on('click', makeLoading)

  #Generated tour
  $('.description').removeClass('opened').addClass('closed')
  $('.toggle-btn').removeClass('opened').addClass('closed').on('click', openDescription)


$(initialize)