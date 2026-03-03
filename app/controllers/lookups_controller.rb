# Handles address-based representative lookups via US Census Geocoder API.
# Returns results inside a Turbo Frame for inline display on the homepage.
class LookupsController < ApplicationController
  def create
    @address = params[:address].to_s.strip
    @representatives = CensusGeocoder::DistrictLookup.new.call(@address)
  rescue CensusGeocoder::DistrictLookup::OutsideUtahError => e
    @error = e.message
  rescue CensusGeocoder::DistrictLookup::InvalidAddressError => e
    @error = e.message
  rescue ApiClient::ApiError => e
    Rails.logger.error("[LookupsController] Census Geocoder error: #{e.message}")
    @error = "Something went wrong looking up your address. Please try again later."
  end
end
