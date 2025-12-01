class QuestionsController < ApplicationController
  # セッションの読み込みを共通化
  before_action :load_session!, only: [:ai_answer, :answer]

  def start
    # 新規作成時は明示的に空の配列とハッシュで作成
    session = Session.create!(messages: [], state: {})
    service = OpenaiChatService.new(session)
    payload = service.start_conversation
  
    render json: payload.merge(session_id: session.uuid)
  end

  # answerアクションに統一（ai_answerもこちらへルーティングするか、aliasにする）
  def answer
    # フロントエンドから送られるキーが 'question' のままであればそのままでOK
    # ※実態は「ユーザーの選択」なので変数名は user_selection としました
    user_selection = params.require(:question)
    
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
    
    # ★重要: ここでデータがリセットされていないかモデルを確認してください
    @session.ensure_state!
    @session.ensure_messages!
  end
end