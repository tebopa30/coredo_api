class HistoryController < ApplicationController
  def index
    session_id = params[:session_id]
    answers = Answer.includes(:question, :option).where(session_id:).order(:created_at)
    render json: answers.map { |a|
      { question: a.question.text, chosen: a.option.text, at: a.created_at }
    }
  end
end
