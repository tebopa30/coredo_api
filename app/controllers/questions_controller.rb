class QuestionsController < ApplicationController
  def start
    session = Session.create!(messages: [], state: {})
    service = OpenaiChatService.new(session)
    first_q = service.generate_next_questions
    parsed  = first_q.is_a?(String) ? JSON.parse(first_q) : first_q

    render json: {
      session_id: session.uuid,
      next_questions: Array(parsed)
    }
  end

  def ai_answer
    load_session!
    question = params.require(:question)
    service  = OpenaiChatService.new(@session)
    payload  = service.reply_to(question)
    render json: payload
  end

  def answer
    load_session!
    question = params.require(:question)
    service  = OpenaiChatService.new(@session)
    payload  = service.reply_to(question)
    render json: payload
  end

  private

  def load_session!
    uuid = params[:session_id] || params[:id] || params[:uuid]
    raise ActionController::ParameterMissing, "session_id" unless uuid
    @session = Session.find_by!(uuid: uuid)
    @session.ensure_state!
    @session.ensure_messages!
  end
end