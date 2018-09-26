class AddressCheckerController < ApplicationController
  def check
    render partial: 'result'
  end
end
