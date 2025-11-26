class AnswersController < ApplicationController
  def create
    session = Session.find_by!(uuid: params[:session_id])
    service = OpenaiChatService.new(session)
  
    user_answer =
      case params[:option_id]
      when "light" then "あっさり"
      when "rich"  then "こってり"
      else params[:answer_text]
      end
  
    result_text = service.reply_to(user_answer)
    next_questions = service.generate_next_questions
  
    if next_questions.present?
      render json: { next_questions: next_questions }
    else
      # finish 判定はここではしない。必ず String を返す
      render json: { result: result_text }
    end
  end

  def finish
    session = Session.find_by!(uuid: params[:session_id])
    service = OpenaiChatService.new(session)

    dish_name = params[:question] || params[:answer_text]
    result_text = service.reply_to(dish_name)

    client = OpenAI::Client.new
    image_response = client.images.generate(
      parameters: {
        model: "gpt-image-1",
        prompt: "#{result_text}の美味しそうな写真、リアルで高品質な料理写真",
        size: "512x512"
      }
    )
    image_url = image_response.dig("data", 0, "url")

    session.update!(finished_at: Time.current)

    # Flutter 側は Map 前提で受け取る
    render json: {
      result: {
        name: result_text,
        recipe: "レシピは後ほど追加予定です",
        image_url: image_url
      }
    }
  end
end