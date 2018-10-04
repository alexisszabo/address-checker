// Place all the behaviors and hooks related to the matching controller here.
//= require choices.js/assets/scripts/dist/choices

document.addEventListener("turbolinks:load", function () {
  new Choices(document.getElementById('language-select'), {removeItemButton: true, paste: false, });
});