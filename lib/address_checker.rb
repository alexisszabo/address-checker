require 'csv'
require 'amatch'
include Amatch

##### Alright, so this is taken from a quickly hacked together script
##### In the future we need to:
#####  - Store stuff in the database instead of files

module AddressChecker

  public

  def check_addresses_from_csv(csv_string, country, province, valid_languages)
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

    CSV.parse(csv_string, headers: true, col_sep: "\t", quote_char: '|') do |row|
      address_without_suite = sanitize_address(row['Address'])
      street_name = address_without_suite.split(/\s/).drop(1).join(' ')
      original_address = format_address(row['Suite'], row['Address'])
      address = format_address(sanitize_suite(row['Suite']), sanitize_address(row['Address']))

      if row['Status'] == 'Valid' || row['Status'] == 'New'

        bad_address_format << {original: original_address, sanitized: address} if original_address != address && street_name.split.length >= 2

        if street_name_in_city[row['City']]
          unless street_name_in_city[row['City']][street_name]
            alternate_cities = []
            street_name_in_city.keys.each do |city|
              alternate_cities << city if street_name_in_city[city][street_name]
            end
            if alternate_cities.length > 0
              wrong_cities << ["#{address}, #{row['City']}", alternate_cities.join(', or ')]
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
      all_database_addresses[address] = {status: row['Status'], language: row['Language'], date_modified: DateTime.parse(row['Modified'])}
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

  private

  def format_address(suite, address)
    suite ? "#{suite}, #{address}" : address
  end

  def sanitize_address(address)
    ##### Remove any Trailing Periods or whitespace
    address = address.chomp('.')
    address = address.chomp(' ')
    
    ##### Capitalize the first letter of any words that don't being with a number
    address = address.gsub(/\S+/) { |word| /^[0-9]/.match(word) ? word : word[0].capitalize + word[1..-1] }

    ##### Use preferred street names
    [
      {starts_with: 'Cres',      replace_with: 'Crescent'},
      {starts_with: 'Dr',        replace_with: 'Dr'},
      {starts_with: 'Ave',       replace_with: 'Ave'},
      {starts_with: 'Ct',        replace_with: 'Crt'},
      {starts_with: 'Court',     replace_with: 'Crt'},
      {starts_with: 'Boulevard', replace_with: 'Blvd'},
      {starts_with: 'Cl',        replace_with: 'Close'},
      {starts_with: 'Road',      replace_with: 'Rd'},
      {starts_with: 'Lane',      replace_with: 'Ln'},
      {starts_with: 'Square',    replace_with: 'Sq'},
      {starts_with: 'Gr',        replace_with: 'Green'},
      {starts_with: 'St',        replace_with: 'St'},
      {starts_with: 'Place',     replace_with: 'Pl'},
    ].each do |fix|
      address = replace_street_name(address, fix[:starts_with], fix[:replace_with])
    end

    address
  end

  def replace_street_name(address, search, replace)
    address.gsub(Regexp.new('(\s+)'+search+'\S*$', Regexp::IGNORECASE), '\\1'+replace)
  end

  def sanitize_suite(suite)
    suite 
  end
end
