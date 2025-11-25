class QuestionsController < ApplicationController
  def start
    session = Session.create!(started_at: Time.current)
    q = Question.order(:order_index).first
    render json: serialize_question(q).merge(session_id: session.uuid)
  end

  # AIに次の質問候補を生成させる
  def next_question
    session = Session.find_by!(uuid: params[:session_id])
    service = OpenaiChatService.new(session)
    questions = service.generate_next_questions
    render json: { next_questions: questions }
  end

  # ユーザーが選んだ質問に対して最終回答を返す
  def answer
    session = Session.find_by!(uuid: params[:session_id])
    service = OpenaiChatService.new(session)
    result = service.reply_to(params[:question])
    render json: { result: result }   # ← Flutter側と合わせる
  end

  def ai_answer
    session = Session.find_by!(uuid: params[:session_id])
    service = OpenaiChatService.new(session)

    # ユーザーが選んだ質問に対して最終回答テキストを生成
    result_text = service.reply_to(params[:question])

    # OpenAIの画像生成APIを呼び出す
    client = OpenAI::Client.new
    image_response = client.images.generate(
      parameters: {
        model: "gpt-image-1",
        prompt: "#{result_text}の美味しそうな写真、リアルで高品質な料理写真", # 回答内容をもとに画像生成
        size: "512x512"
      }
    )

    image_url = image_response.dig("data", 0, "url")

    render json: { result: result_text, image_url: image_url }
  end


  def show
    q = Question.find(params[:id])
    render json: serialize_question(q)
  end

  private

  def serialize_question(q)
    {
      id: q.id,
      text: q.text,
      routing: q.routing,
      options: q.options.map { |o|
        {
          id: o.id,
          text: o.text,
          next_question_id: o.next_question_id,
          dish_id: o.dish_id
        }
      }
    }
  end
end