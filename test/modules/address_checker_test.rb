require 'address_checker'
include AddressChecker

class AddressCheckerTest < ActiveSupport::TestCase
  test "should remove periods in address" do
    assert_equal "1234 Sesame St", sanitize_address("1234. Sesame. St.").first
  end  

  test "should remove white space at beginning of address" do
    assert_equal "1234 Sesame St", sanitize_address(" 1234 Sesame St").first
  end

  test "should remove white space at end of address" do
    assert_equal "1234 Sesame St", sanitize_address("1234 Sesame St ").first
  end

  test "should remove double space in address" do
    assert_equal "1234 Sesame St", sanitize_address("1234   Sesame   St").first
  end

  test "should capitalize street name in address" do
    assert_equal "1234 Sesame St", sanitize_address("1234 sesame st").first
  end

  test "should replace Direction at end with abbreviation" do
    assert_equal "1234 Sesame St W", sanitize_address("1234 Sesame St West").first
  end

  test "should replace direction in middle with abbreviation" do
    assert_equal "1234 Sesame W St", sanitize_address("1234 Sesame West St").first
  end

  test "should replace direction at beginning with abbreviation" do
    assert_equal "1234 NE Sesame St", sanitize_address("1234 Northeast Sesame St").first
  end

  test "should NOT replace direction when direction is the street name" do
    assert_equal "1234 North Rd", sanitize_address("1234 North Rd").first
  end

  test "should move direction at end in between street name and identifier" do
    assert_equal "1234 E 49th Ave", sanitize_address("1234 49th Ave East").first
  end

  test "should capitalize letter in numeric street name" do
    assert_equal "1234 158A St", sanitize_address("1234 158a St").first
  end
end
