class AnswersController < ApplicationController
  def create
    session_id = params.require(:session_id)
    option = Option.find(params.require(:option_id))
    Answer.create!(session_id:, question_id: option.question_id, option_id: option.id)

    # 次のステップ判定
    if option.next_question_id.present?
      next_q = Question.find(option.next_question_id)
      render json: { next_question: { id: next_q.id, text: next_q.text } }
    elsif option.dish_id.present?
      dish = Dish.find(option.dish_id)
      render json: { result: { dish_id: dish.id, name: dish.name } }
    else
      render json: { message: "回答が未設定" }, status: :unprocessable_entity
    end
  end
end
