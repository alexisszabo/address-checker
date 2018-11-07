require 'address_checker'
include AddressChecker

class AddressCheckerController < ApplicationController
  def process_addresses
    @messages = get_error_messages

    if @messages.blank?
      address_rows = []

      CSV.parse(params[:addresses], headers: true, col_sep: "\t", quote_char: '|') { |row| address_rows << row }

      if params[:mode] == 'Check Addresses'
        render json: { html: render_result_view_to_string(address_rows) }
      else
        render json: { csv_string: generate_csv(address_rows) }
      end
    else
      render json: { html: render_to_string(partial: 'wrong_input') }
    end
  end

  def get_error_messages
    messages = []
    messages << 'Please select the primary language of your account' if params[:kind] != 'Local' && params[:mode] != "Create CSV" && !params[:valid_languages]

    if params[:addresses].present?
      headers = params[:addresses].lines.first
      has_local_headers = (headers.match(/Address_ID\s+Suite\s+Address\s+City\s+Province\s+Postal_code\s+Country\s+Notes\s+Kind\s+Status\s+Account\s+Language/) != nil)
      has_foreign_language_headers = (headers.match(/Address_ID\s+Territory_ID\s+Language\s+Status\s+Name\s+Suite\s+Address\s+City\s+Province\s+Postal_code\s+Country\s+Latitude\s+Longitude\s+Telephone	Owner\s+Notes\s+Notes_private\s+Account\s+Created\s+Modified\s+Contacted\s+Geocoded\s+Territory_number\s+Territory_description/) != nil)

      if !has_local_headers && !has_foreign_language_headers
        messages << 'Unrecognized format. Are you sure you cut and paste all exported addresses, including the header line?'
      elsif has_foreign_language_headers && params[:kind] == 'Local'
        messages << 'You specified a Local account, but your addresses look like a Foreign Language account. Please change your selection.'
      elsif has_local_headers && params[:kind] == 'Foreign-language'
        messages << 'You specified a Foreign Language account, but your addresses look like a Local account. Please change your selection.'
      end
    else
      messages << 'Woops! Look like you forgot to paste in your addresses!'
    end
    messages
  end

  def render_result_view_to_string(address_rows)
    result = check_addresses(address_rows, params[:kind], params[:country], params[:province], params[:valid_languages], params[:statuses])
    @can_auto_fix = (params[:kind] == 'Foreign-language')
    @duplicate_addresses = result[:duplicate_addresses]
    @unknown_street_name = result[:unknown_street_name]
    @unknown_cities      = result[:unknown_cities]
    @wrong_languages     = result[:wrong_languages]
    @wrong_cities        = result[:wrong_cities]
    @needs_to_be_blanked = result[:needs_to_be_blanked]
    @change_to_valid     = result[:change_to_valid]
    @needs_manual_fixes  = [@duplicate_addresses, @unknown_street_name, @unknown_cities, @wrong_languages, @wrong_cities, @needs_to_be_blanked].any? { |a| a.length > 1 }
    @bad_address_format  = result[:bad_address_format]
    @needs_auto_fixes    = @bad_address_format.length > 0
    @has_problems        = (@needs_manual_fixes || @needs_auto_fixes)

    render_to_string partial: 'result'
  end

  def generate_csv(address_rows)
    address_rows = fix_addresses(address_rows, params[:purpose], params[:export_tag], params[:autofix], params[:remove], params[:change_to_valid])
    return convert_addresses_to_csv_string(address_rows)
  end
end
