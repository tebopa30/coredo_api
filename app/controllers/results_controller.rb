class ResultsController < ApplicationController
  def show
    session_id = params[:session_id]
    last = Answer.where(session_id:).order(:created_at).last
    if last&.option&.dish_id
      dish = Dish.find(last.option.dish_id)
      render json: { dish: { id: dish.id, name: dish.name, cuisine: dish.cuisine, description: dish.description } }
    else
      render json: { message: "まだ結果がありません" }, status: :not_found
    end
  end
end
