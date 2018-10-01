require 'address_checker'
include AddressChecker

class AddressCheckerController < ApplicationController
  def check
    params[:valid_languages] = [] #Hack

    @messages = []

    if params[:addresses].present?
      headers = params[:addresses].lines.first
      has_local_headers = (headers.match(/Address_ID\s+Suite\s+Address\s+City\s+Province\s+Postal_code\s+Country\s+Notes\s+Kind\s+Status\s+Account\s+Language/) != nil)
      has_foreign_language_headers = (headers.match(/Address_ID\s+Territory_ID\s+Language\s+Status\s+Name\s+Suite\s+Address\s+City\s+Province\s+Postal_code\s+Country\s+Latitude\s+Longitude\s+Telephone	Owner\s+Notes\s+Notes_private\s+Account\s+Created\s+Modified\s+Contacted\s+Geocoded\s+Territory_number\s+Territory_description/) != nil)

      if !has_local_headers && !has_foreign_language_headers
        @messages << 'Unrecognized format. Are you sure you cut and paste all exported addresses, including the header line?'
      elsif has_foreign_language_headers && params[:kind] == 'Local'
        @messages << 'You specified a Local account, but your addresses look like a Foreign Language account. Please change your selection.'
      elsif has_local_headers && params[:kind] == 'Foreign-language'
        @messages << 'You specified a Foreign Language account, but your addresses look like a Local account. Please change your selection.'
      end
    else
      @messages << 'Woops! Look like you forgot to paste in your addresses!'
    end

    if @messages.blank?
      addresses = []
      @can_auto_fix = (params[:kind] == 'Foreign-language')
      CSV.parse(params[:addresses], headers: true, col_sep: "\t", quote_char: '|') { |row| addresses << row }
      result = check_addresses(addresses, params[:kind], params[:country], params[:province], params[:valid_languages], params[:statuses])

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
      render partial: 'result'
    else
      render partial: 'wrong_input'
    end
  end
end
