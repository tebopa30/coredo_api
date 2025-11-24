class AnswersController < ApplicationController
  def create
    session = Session.find_by!(uuid: params.require(:session_id))
    option = Option.find(params.require(:option_id))

    Answer.create!(
      session_id: session.id,
      question_id: option.question_id,
      option_id: option.id
    )

    if option.next_question_id.present?
      next_q = Question.find(option.next_question_id)
      render json: serialize_question(next_q).merge(session_id: session.uuid)
    elsif option.dish_id.present?
      dish = Dish.find(option.dish_id)
      session.update!(dish_id: dish.id, finished_at: Time.current)
      render json: { result: { dish_id: dish.id, name: dish.name } }
    else
      render json: { message: "回答が未設定" }, status: :unprocessable_entity
    end
  end

  private

  def serialize_question(q)
    {
      id: q.id,
      text: q.text,
      routing: q.routing,
      options: q.options.map { |o|
        {
          id: o.id,
          text: o.text,
          next_question_id: o.next_question_id,
          dish_id: o.dish_id
        }
      }
    }
  end

end
