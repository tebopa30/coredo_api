class ResultsController < ApplicationController
  def show
    session = Session.find_by!(uuid: params[:session_id])

    # 最後の assistant メッセージを取得
    last_ai = session.messages.reverse.find { |m| m["role"] == "assistant" }

    parsed = JSON.parse(last_ai["content"]) rescue nil

    # 統一フォーマット（title / description / extra）に対応
    if parsed.is_a?(Hash) && parsed["title"] && parsed["description"]
      render json: parsed
    else
      render json: { error: "まだ結果がありません" }, status: :not_found
    end
  end
end