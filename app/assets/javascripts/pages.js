import Choices from 'choices.js'

// Place all the behaviors and hooks related to the matching controller here.
document.addEventListener('turbolinks:load', function () {
  new Choices(document.getElementById('language-select'), { removeItemButton: true, paste: false })
})
