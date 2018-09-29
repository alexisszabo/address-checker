require 'address_checker'
include AddressChecker

class AddressCheckerController < ApplicationController
  def check
    params[:valid_languages] = [] #Hack

    addresses = []
    CSV.parse(params[:addresses], headers: true, col_sep: "\t", quote_char: '|') { |row| addresses << row }

    @has_addresses = addresses.length > 0

    if @has_addresses
      result = check_addresses(addresses, params[:country], params[:province], params[:valid_languages], params[:statuses])

      @duplicate_addresses = result[:duplicate_addresses]
      @unknown_street_name = result[:unknown_street_name]
      @unknown_cities      = result[:unknown_cities]
      @wrong_languages     = result[:wrong_languages]
      @wrong_cities        = result[:wrong_cities]
      @needs_to_be_blanked = result[:needs_to_be_blanked]
      @needs_manual_fixes  = [@duplicate_addresses, @unknown_street_name, @unknown_cities, @wrong_languages, @wrong_cities, @needs_to_be_blanked].any? { |a| a.length > 1 }

      @bad_address_format  = result[:bad_address_format]
      @needs_auto_fixes    = @bad_address_format.length > 1

      @has_problems        = (@needs_manual_fixes || @needs_auto_fixes)
    end

    render partial: 'result'
  end
end
