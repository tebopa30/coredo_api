class AnswersController < ApplicationController
  before_action :load_session!

  def create
    answer  = params.require(:answer)
    service = OpenaiChatService.new(@session)
    payload = service.reply_to(answer)
    render json: payload
  end

  def finish
    service = OpenaiChatService.new(@session)
    # 強制的に最終提案のみ返させたいケースのため、空文字でも可
    payload = service.reply_to(params[:answer].to_s)
    render json: payload
  end

  private

  def load_session!
    uuid = params[:session_id] || params[:uuid]
    raise ActionController::ParameterMissing, "session_id" unless uuid
    @session = Session.find_by!(uuid: uuid)
    @session.ensure_state!
  end
end