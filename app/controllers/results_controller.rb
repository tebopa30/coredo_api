class ResultsController < ApplicationController
  def show
    session_id = params[:session_id]
    last = Answer.where(session_id:).order(:created_at).last
    if last&.option&.dish_id
      dish = Dish.find(last.option.dish_id)

      # finish と同じ構造に統一
      render json: {
        result: {
          name: dish.name,
          recipe: dish.description || "レシピは後ほど追加予定です",
          image_url: dish.image_url # Dish モデルに image_url カラムがある前提
        }
      }
    else
      render json: { message: "まだ結果がありません" }, status: :not_found
    end
  end
end
