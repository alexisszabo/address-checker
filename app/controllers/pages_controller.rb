class PagesController < ApplicationController
  def index
    @countries = ['Canada']
    @provinces = ['British Columbia']
    @languages = %w(
      American\ Sign\ Language\ (ASL)
      Amharic
      Arabic
      Bengali
      Cebuano
      Chinese\ Cantonese
      Chinese\ Mandarin
      French
      Hindi
      Iloko
      Italian
      Japanese
      Korean
      Persian
      Polish
      Portuguese
      Punjabi
      Russian
      Spanish
      Swahili
      Tagalog
      Tamil
      Vietnamese
      Yoruba
    )
    @statuses_default_on = ['New', 'Valid', 'Do not call']
    @statuses_default_off = ['Moved', 'Duplicate', 'Not valid']
    @remove_options = %w[Language Name Telephone Postal_code Notes Notes_private]
  end
end
