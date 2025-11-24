class QuestionsController < ApplicationController
  def start
    session = Session.create!(
      uuid: SecureRandom.uuid,
      started_at: Time.current
    )

    q = Question.order(:order_index).first
    render json: serialize_question(q).merge(session_id: session.uuid)
  end

  def show
    q = Question.find(params[:id])
    render json: serialize_question(q)
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