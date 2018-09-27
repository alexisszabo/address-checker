require 'address_checker'
include AddressChecker

class AddressCheckerController < ApplicationController
  def check
    params[:valid_languages] = [] #Hack

    AddressChecker.check_addresses_from_csv(params[:addresses],
                                            params[:country],
                                            params[:province],
                                            params[:valid_languages])
    render partial: 'result'
  end
end
