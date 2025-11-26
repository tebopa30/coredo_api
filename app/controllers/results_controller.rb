class ResultsController < ApplicationController
  def show
    session_id = params[:session_id]
    last = Answer.where(session_id:).order(:created_at).last

    if last&.option&.dish_id
      dish = Dish.find(last.option.dish_id)

      render json: {
        result: {
          dish: dish.name,
          description: dish.description || "説明は後ほど追加予定です",
          image_url: dish.image_url
        }
      }
    else
      render json: { error: "まだ結果がありません" }, status: :not_found
    end
  end
end
