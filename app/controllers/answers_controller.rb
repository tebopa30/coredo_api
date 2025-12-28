class AnswersController < ApplicationController
  before_action :load_session!

  def create
    selected = params[:option_id] || params.dig(:answer, :option_id)
    service = OpenaiChatService.new(@session)
    payload = service.reply_to(selected)
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
