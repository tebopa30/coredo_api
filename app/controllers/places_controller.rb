class PlacesController < ApplicationController
  include HTTParty
  base_uri 'https://maps.googleapis.com/maps/api'

  def search
    query = params[:query]
    lat   = params[:lat]
    lng   = params[:lng]
    response = self.class.get("/place/textsearch/json", {
      query: {
        query: "#{query} レストラン",
        location: "#{lat},#{lng}",
        radius: 4000, # 半径4km
        language: "ja",
        key: ENV['GOOGLE_API_KEY']
      }
    })
    Rails.logger.info response.parsed_response
    render json: response.parsed_response
  end

  def geocode
    address = params[:address]
    response = self.class.get("/geocode/json", {
      query: { address: address, key: ENV['GOOGLE_API_KEY'] }
    })
    render json: response.parsed_response
  end

  def directions
    origin = params[:origin]
    destination = params[:destination]
    response = self.class.get("/directions/json", {
      query: { origin: origin, destination: destination, key: ENV['GOOGLE_API_KEY'] }
    })
    render json: response.parsed_response
  end

  def details
    place_id = params[:place_id]
    response = self.class.get("/place/details/json", {
      query: {
        place_id: place_id,
        language: "ja",
        key: ENV['GOOGLE_API_KEY']
      }
    })
    result = response.parsed_response["result"]
    render json: {
      name: result["name"],
      address: result["formatted_address"],
      phone: result["formatted_phone_number"],
      rating: result["rating"],
      photos: result["photos"],
      reviews: result["reviews"]
    }
  end
  
end