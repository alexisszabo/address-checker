class PagesController < ApplicationController
  def index
    @countries = ['Canada']
    @provinces = ['British Columnbia']
    @statuses_default_on = ['New', 'Valid', 'Do not call']
    @statuses_default_off = ['Moved', 'Duplicate', 'Not valid']
  end
end
