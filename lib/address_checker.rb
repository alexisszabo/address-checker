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
            sanitized_address = sanitize_address(line.chomp)
            street_name_in_city[city] ||= {}
            street_name_in_city[city][sanitized_address] = true
            full_street_name_in_city[city] ||= {}
            street_name_without_identifier = sanitized_address.split[0..-2].join(' ')
            ambiguous_names[city] ||= {}
            ambiguous_names[city][street_name_without_identifier] = true if full_street_name_in_city[city][street_name_without_identifier]
            full_street_name_in_city[city][street_name_without_identifier] = sanitized_address
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
      address_without_suite = sanitize_address(row['Address'])
      street_name = address_without_suite.split(/\s/).drop(1).join(' ')
      original_address = format_address(row['Suite'], row['Address'])
      address = format_address(sanitize_suite(row['Suite']), sanitize_address(row['Address']))

      if kind == 'Local' || statuses.include?(row['Status'])
        bad_address_format << {original: original_address, sanitized: address} if original_address != address && street_name.split.length >= 2

        if street_name_in_city[row['City']]
          unless street_name_in_city[row['City']][street_name]
            alternate_cities = []
            street_name_in_city.keys.each do |city|
              alternate_cities << city if street_name_in_city[city][street_name]
            end
            if alternate_cities.length > 0
              wrong_cities << {address: "#{address}, #{row['City']}", suggested_city: alternate_cities.join(', or ')}
            else
              possibilities = []
              street_name_in_city[row['City']].each do |master_street, val|
                m = Jaro.new(master_street)
                possibilities << master_street if m.match(street_name) > 0.84
              end
              unknown_street_name << {address: "#{address}, #{row['City']}", possibilities: possibilities}
            end
          end
        else
          unknown_cities << "#{address}, #{row['City']}"
        end

        if row['Name'] || row['Telephone'] || row['Postal_code']
          hash = {address: address}
          hash[:remove_name] = row['Name'] if row['Name']
          hash[:remove_telephone] = row['Telephone'] if row['Telephone']
          hash[:remove_postal_code] = row['Postal_code'] if row['Postal_code']
          needs_to_be_blanked << hash
        end


        wrong_languages << "#{address}: #{row['Language']}" unless valid_languages.include? row['Language']
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

  def fix_addresses(address_hash)
    address_hash.each do |id,a|
      a['Address'] = sanitize_address(a)
    end
    address_hash
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
      {starts_with: %w(Cres),          replace_with: 'Cres'},
      {starts_with: %w(Court Ct),      replace_with: 'Crt'},
      {starts_with: %w(Dr),            replace_with: 'Dr'},
      {starts_with: %w(Lane),          replace_with: 'Ln'},
      {starts_with: %w(Place),         replace_with: 'Pl'},
      {starts_with: %w(Road),          replace_with: 'Rd'},
      {starts_with: %w(Square),        replace_with: 'Sq'},
      {starts_with: %w(St),            replace_with: 'St'},
    ]

  def format_address(suite, address)
    suite ? "#{suite}, #{address}" : address
  end

  def sanitize_address(address)
    ##### Remove any Trailing Periods or whitespace
    address = address.chomp('.')
    address = address.chomp(' ')

    ##### Capitalize the first letter of any words that don't being with a number
    address = address.gsub(/\S+/) { |word| /^[0-9]/.match(word) ? word : word[0].capitalize + word[1..-1] }

    ##### If street name has a direction at the end, put it in front of the street name (Vancouver)
    ##### ie. 1234 49th Ave East -> 1234 E 49th Ave
    if (match = address.match(/(^[0-9]+)\s+([0-9]+)(st|nd|rd|th)\s+(\w+)\s+(East|West|North|South)/))
      number, street1, street2, street3, direction = match.captures
      address = "#{number} #{direction[0].capitalize} #{street1}#{street2} #{street3}"
    end

    ##### If street has a single letter, capitalize it (Surrey, Maple Ridge)
    ##### ie. 1234 158a St -> 1234 158A St
    if (match = address.match(/^([0-9]+)\s+([0-9]+[a-z])\s+(.*)/))
      number, street1, street2, = match.captures
      address = "#{number} #{street1.upcase} #{street2}"
    end

    ##### Use preferred street names
    @@preferred_street_names.each do |fix|
      fix[:starts_with].each do |starts_with|
        address = replace_street_name(address, starts_with, fix[:replace_with])
      end
    end

    address
  end

  ##### This replaces the street name (assumed to be the last word in the address)
  ##### With the preferred abbreviation
  def replace_street_name(address, search, replace)
    address.gsub(Regexp.new('(\s+)'+search+'\S*$', Regexp::IGNORECASE), '\\1'+replace)
  end

  def sanitize_suite(suite)
    suite 
  end
end
