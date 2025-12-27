class ResultsController < ApplicationController
  def show
    session = Session.find_by!(uuid: params[:session_id])

    # 最後の assistant メッセージを取得
    last_ai = session.messages.reverse.find { |m| m["role"] == "assistant" }

    parsed = JSON.parse(last_ai["content"]) rescue nil

    if parsed.is_a?(Hash) && parsed["result"]
      render json: parsed["result"]
    else
      render json: { error: "まだ結果がありません" }, status: :not_found
    end
  end
end