class AnswersController < ApplicationController
  def create
    session = Session.find_by!(uuid: params.require(:session_id))
    service = OpenaiChatService.new(session)

    # ユーザーの選択肢や質問をAIに渡して回答生成
    question_text = params[:question] || Option.find(params[:option_id]).text
    result_text = service.reply_to(question_text)

    # 画像もAIで生成（gpt-image-1）
    client = OpenAI::Client.new
    image_response = client.images.generate(
        model: "gpt-image-1",
        prompt: "#{result_text}の美味しそうな写真、リアルで高品質な料理写真",
        size: "512x512"
    )
    image_url = image_response.dig("data", 0, "url")

    # セッションを終了状態に更新
    session.update!(finished_at: Time.current)

    render json: {
      result: {
        text: result_text,
        image_url: image_url
      }
    }
  end
end