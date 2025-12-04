class AnswersController < ApplicationController
  before_action :load_session!

  def create
    answer  = params.require(:answer)
    service = OpenaiChatService.new(@session)
    payload = service.reply_to(answer)
    render json: payload
  end

  def finish
    dish = params[:question].to_s
  
    # 抽象ワードはスキップ
    if dish.match?(/感じ|気分|もの/)
      Rails.logger.info("[FINISH SKIP] dish=#{dish.inspect}")
      render json: { status: "skipped", session_id: params[:session_id] }
      return
    end
  
    result_hash = {
      "session_id" => params[:session_id],
      "dish"       => dish,
      "subtype"    => params[:subtype],
      "description"=> params[:description]
    }
  
    render json: { status: "accepted", session_id: result_hash["session_id"] }
  end

  private

  def load_session!
    uuid = params[:session_id] || params[:uuid]
    raise ActionController::ParameterMissing, "session_id" unless uuid
    @session = Session.find_by!(uuid: uuid)
    @session.ensure_state!
  end
end
