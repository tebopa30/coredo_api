class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: "not_found", message: e.message }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: "bad_request", message: e.message }, status: :bad_request
  end

  rescue_from StandardError do |e|
    Rails.logger.error("[API ERROR] #{e.class}: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end
end