require 'csv'
require 'amatch'
include Amatch

module AddressChecker
  def check_addresses(addresses, kind, country, province, valid_languages, statuses)
    ##### Load all the street names for cities for this country province
    street_name_in_city = {}
    full_street_name_in_city = {}
    ambiguous_names = {}

    dir = "#{Rails.root}/lib/city_streets/#{country.gsub(/\s/,'_')}/#{province.gsub(/\s/,'_')}/"
    Dir.entries(dir).each do |filename|
      if /\S+\.txt/.match(filename)
        city = filename.gsub('_',' ').gsub(/\.txt$/, '').gsub(/\S+/) {|word| word[0].capitalize + word[1..-1] }
        File.open(dir+'/'+filename, 'r') do |f|
          f.each_line do |line|
            sanitized_street_name = sanitize_street_name(line.chomp).first
            street_name_in_city[city] ||= {}
            street_name_in_city[city][sanitized_street_name] = true
            full_street_name_in_city[city] ||= {}
            street_name_without_identifier = sanitized_street_name.split[0..-2].join(' ')
            ambiguous_names[city] ||= {}
            ambiguous_names[city][street_name_without_identifier] = true if full_street_name_in_city[city][street_name_without_identifier]
            full_street_name_in_city[city][street_name_without_identifier] ||= []
            full_street_name_in_city[city][street_name_without_identifier] << sanitized_street_name
          end
        end
      end
    end

    duplicate_addresses = []
    bad_address_format = []
    unknown_street_name = []
    unknown_cities = []
    wrong_languages = []
    wrong_cities = []
    needs_to_be_blanked = []
    all_database_addresses = {}

    addresses.each do |row|
      next unless row['Address']
      next if kind == 'Local' && row['Kind'] != 'Local'
      address_without_suite, reason = sanitize_address(row['Address'])
      street_name = address_without_suite.split(/\s/).drop(1).join(' ')
      street_name_without_identifier = street_name.split[0..-2].join(' ')
      original_address = format_address(row['Suite'], row['Address'])
      address = format_address(sanitize_suite(row['Suite']), address_without_suite)

      if kind == 'Local' || statuses.include?(row['Status'])
        bad_address_format << {original: original_address, sanitized: address, reason: reason} if original_address != address && street_name.split.length >= 2

        if street_name_in_city[row['City']]
          unless street_name_in_city[row['City']][street_name]
            alternate_cities = []
            street_name_in_city.keys.each do |city|
              alternate_cities << city if street_name_in_city[city][street_name]
            end
            if alternate_cities.length > 0
              wrong_cities << {address: "#{address}, #{row['City']}", suggested_city: alternate_cities.join(', or ')}
            else
              ##### If there is the same street name, but with a different identifier, in the same city, suggest that
              unless (possibilities = full_street_name_in_city[row['City']][street_name_without_identifier])
                possibilities = []
                ##### Otherwise, check spelling
                street_name_in_city[row['City']].each do |master_street, val|
                  m = Jaro.new(master_street)
                  possibilities << master_street if m.match(street_name) > 0.84
                end
              end
              unknown_street_name << {address: "#{address}, #{row['City']}", possibilities: possibilities}
            end
          end
        else
          unknown_cities << "#{address}, #{row['City']}"
        end

        if row['Name'] || row['Telephone'] || row['Postal_code']
          hash = {address: address}
          hash[:name] = row['Name'] if row['Name']
          hash[:telephone] = row['Telephone'] if row['Telephone']
          hash[:postal_code] = row['Postal_code'] if row['Postal_code']
          needs_to_be_blanked << hash
        end

        if kind != 'Local' && %w[New Valid Do_not_call].include?(row['Status'])
          wrong_languages << "#{address}: #{row['Language']}" unless valid_languages.include? row['Language']
        end
        duplicate_addresses << address if all_database_addresses[address]
      end
      all_database_addresses[address] = true
    end

    {
      duplicate_addresses: duplicate_addresses,
      bad_address_format:  bad_address_format,
      unknown_street_name: unknown_street_name,
      unknown_cities:      unknown_cities,
      wrong_languages:     wrong_languages,
      wrong_cities:        wrong_cities,
      needs_to_be_blanked: needs_to_be_blanked
    }

  end

  def fix_addresses(address_rows, purpose, export_tag, fix_address, remove_options)
    new_address_rows = []
    address_rows.each do |row|
      ##### If an export tag is defined, we only export addresses that match the tag in the territory description
      next if purpose == 'Export' && export_tag.present? && !row['Territory_description'].try(:match, /(^|\s+)#{export_tag}($|\s+)/)

      changed = false
      if fix_address
        new_address = sanitize_address(row['Address']).first
        if new_address != row['Address']
          row['Address'] = new_address
          changed = true
        end
      end
      remove_options&.each do |key|
        if row[key].present?
          row[key] = ''
          changed = true
        end
      end
      next if purpose == 'Import' && !changed

      ##### If we're export addresses to another account, delete the keys associated with existing addresses/territories
      ##### We only need to clear the ones that will get exported later
      if purpose == 'Export'
        row['Address_ID'] = ''
        row['Territory_ID'] = ''
      end

      new_address_rows << row
    end
    new_address_rows
  end

  def convert_addresses_to_csv_string(addresses)
    fields = %w[Address_ID Territory_ID Language Status Name Suite Address City Province Postal_code Country Latitude Longitude Telephone Notes Notes_private]
    CSV.generate do |csv|
      csv << fields
      addresses.each do |address|
        address_array = []
        fields.each do |field|
          address_array << address[field]
        end
        csv << address_array
      end
    end
  end

  private

  ##### These are taken from:
  #####   Canada Post "Symbols and Abbreviations Recognized by Canada Post"
  #####   https://www.canadapost.ca/tools/pg/manual/PGaddress-e.asp?ecid=murl10006450
  @@preferred_street_names =
    [
      {starts_with: %w(Ave),           replace_with: 'Ave'},
      {starts_with: %w(Boulevard),     replace_with: 'Blvd'},
      {starts_with: %w(Centre Center), replace_with: 'Ctr'},
      {starts_with: %w(Cl),            replace_with: 'Close'},
      {starts_with: %w(Cr[^t]),        replace_with: 'Cres'},
      {starts_with: %w(Court Ct),      replace_with: 'Crt'},
      {starts_with: %w(Dr),            replace_with: 'Dr'},
      {starts_with: %w(Highway),       replace_with: 'Hwy'},
      {starts_with: %w(Lane),          replace_with: 'Ln'},
      {starts_with: %w(Place),         replace_with: 'Pl'},
      {starts_with: %w(Road),          replace_with: 'Rd'},
      {starts_with: %w(Square),        replace_with: 'Sq'},
      {starts_with: %w(St),            replace_with: 'St'},
      {starts_with: %w(Wy),            replace_with: 'Way'}
    ]

  def format_address(suite, address)
    suite ? "#{suite}, #{address}" : address
  end

  def sanitize_address(address) 
    reason = ''

    ##### Full address checks:
    address, reason = change_with_reason(address, reason, "Remove Double Space") do |a|
      a.gsub(/\s\s/, ' ')
    end
    address, reason = change_with_reason(address, reason, "Remove Extra Space at Beginning") do |n|
      n.lstrip
    end

    if match = address.match('(^|\s+)(\S+)\s(.*)')
      nothing, number, street_name = match.captures

      ##### Number only check:
      number, reason = change_with_reason(number, reason, "Remove Period") do |n|
        n.delete('.')
      end

      ###### Street Name Only checks:
      street_name, reason = sanitize_street_name(street_name)

      ["#{number} #{street_name}", reason]
    else
      [address, reason]
    end
  end

  ##### This routine is called stand-alone (to normalize addresses when loading from cities)
  ##### It is also called as part of sanitize_address for checking addresses
  def sanitize_street_name(street_name)
    reason = ''

    street_name, reason = change_with_reason(street_name, reason, "Remove Period") do |s|
      s.delete('.')
    end

    street_name, reason = change_with_reason(street_name, reason, "Remove Extra Space at End") do |s|
      s.rstrip
    end

    street_name, reason = change_with_reason(street_name, reason, "Remove Extra Space at Beginning") do |s|
      s.lstrip
    end

    street_name, reason = change_with_reason(street_name, reason, "Remove Double Space") do |s|
      s.gsub(/\s\s/, ' ')
    end

    street_name, reason = change_with_reason(street_name, reason, "Capitalize Street Name") do |s|
      s.gsub(/\S+/) { |word| /^[0-9]/.match(word) ? word : word[0].capitalize + word[1..-1] }
    end

    ##### Change directions in street_namees unless the direction is the Street Name (ie. 1234 North Rd)
    if street_name.split(/\s+/).length > 2
      street_name, reason = change_with_reason(street_name, reason, "Replace East with E") do |s|
        replace_word_in_sentence(s, 'East', 'E')
      end
      street_name, reason = change_with_reason(street_name, reason, "Replace West with W") do |s|
        replace_word_in_sentence(s, 'West', 'W')
      end
      street_name, reason = change_with_reason(street_name, reason, "Replace North with N") do |s|
        replace_word_in_sentence(s, 'North', 'N')
      end
      street_name, reason = change_with_reason(street_name, reason, "Replace South with S") do |s|
        replace_word_in_sentence(s, 'South', 'S')
      end
      street_name, reason = change_with_reason(street_name, reason, "Replace NorthEast with NE") do |s|
        replace_word_in_sentence(s, 'Northeast', 'NE')
      end
      street_name, reason = change_with_reason(street_name, reason, "Replace NorthWest with NW") do |s|
        replace_word_in_sentence(s, 'Northwest', 'NW')
      end
      street_name, reason = change_with_reason(street_name, reason, "Replace SouthEast with SE") do |s|
        replace_word_in_sentence(s, 'Southeast', 'SE')
      end
      street_name, reason = change_with_reason(street_name, reason, "Replace Southwest with SW") do |s|
        replace_word_in_sentence(s, 'Southwest', 'SW')
      end
    end

    ##### If street name has a direction at the end, put it in front of the street name (Vancouver)
    ##### ie. 49th Ave East -> E 49th Ave
    street_name, reason = change_with_reason(street_name, reason, "Put N/E/W/S in front of Numbered Street") do |s|
      if (match = s.match(/^([0-9]+)(st|nd|rd|th)\s+(\w+)\s+(E|W|N|S)$/))
        street1, street2, street3, direction, rest1, rest2 = match.captures
        "#{direction[0].capitalize} #{street1}#{street2} #{street3}#{rest1}#{rest2}"
      else
        s
      end
    end

    ##### If street has a single letter, capitalize it (Surrey, Maple Ridge, etc)
    ##### ie. 158a St -> 158A St
    street_name, reason = change_with_reason(street_name, reason, "Capitalize Letter in Numbered Street") do |s|
      if (match = s.match(/^([0-9]+[a-z])\s+(.*)/))
        street1, street2, = match.captures
        "#{street1.upcase} #{street2}"
      else
        s
      end
    end

    ##### Use preferred street names
    street_name, reason = change_with_reason(street_name, reason, "Use Preferred Street Name Abbreviation") do |s|
      @@preferred_street_names.each do |fix|
        fix[:starts_with].each do |starts_with|
          ##### This replaces the street name (assumed to be the last word in the address)
          ##### With the preferred abbreviation
          ##### The abbreviation may have N/W/E/S after it, so check for that
          s = s.gsub(Regexp.new('(\s+)' + starts_with + '\S*($|\s(N|W|S|E)$)', Regexp::IGNORECASE), '\\1'+fix[:replace_with]+'\\2')
        end
      end
      s
    end

    [street_name, reason]
  end

  def replace_word_in_sentence(sentence, word, replacement)
    sentence.gsub(/(^|\s+)#{word}($|\s+)/, "\\1#{replacement}\\2")
  end

  def change_with_reason(value, reason, new_reason)
    # Make a copy in case the block changes the value
    original_address = value
    new_address = yield value
    reason = reason.blank? ? new_reason : "#{reason}\n#{new_reason}" if original_address != new_address
    [new_address, reason]
  end

  def sanitize_suite(suite)
    suite
  end
end
