# README

This application is used to clean up address lists in a specific version. It:

* Normalizes addresses
  - Removes unneeded whitespace
  - Capitalizes street names
  - Abbreviates North/East/West/South
  - Uses preferred street abbreviations
  - Replaces misspelled streets
* Suggests manual changes when confidence level is not high for automatic fixing

All changes/suggestions are summarized in the browser after running

The output is a CSV file which can be used to import back into the source
application to overwrite the original addresses

## Dependencies

- Ruby 3.3
- Node 20
- `bundle install`
- `yarn install`

## Database initialization

`rake db:migrate`

## How to run the test suite

`rails test -v`

## Deployment instructions

`cap production deploy`
