class QuestionsController < ApplicationController
  # セッションの読み込みを共通化
  before_action :load_session!, only: [:ai_answer, :answer]

  def start
    mode = params[:mode] || "meal"
  
    session = Session.create!(messages: [], state: {})
    service = OpenaiChatService.new(session)
    payload = service.start_conversation(mode: mode)
  
    render json: payload.merge(session_id: session.uuid)
  end

  # answerアクションに統一（ai_answerもこちらへルーティングするか、aliasにする）
  def answer
    user_selection = params[:option_id] || params[:question]
    raise ActionController::ParameterMissing, "option_id" unless user_selection
  
    service = OpenaiChatService.new(@session)
    payload = service.reply_to(user_selection)
  
    render json: payload
  end
  
  # ai_answer が古いルーティングで必要な場合
  alias_method :ai_answer, :answer

  private

  def load_session!
    uuid = params[:session_id] || params[:id] || params[:uuid]
    raise ActionController::ParameterMissing, "session_id" unless uuid
    
    @session = Session.find_by!(uuid: uuid)
    
    @session.ensure_state!
    @session.ensure_messages!
  end
end