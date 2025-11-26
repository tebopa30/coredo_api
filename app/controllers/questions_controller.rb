class QuestionsController < ApplicationController
  def start
    session = Session.create!(uuid: SecureRandom.uuid, started_at: Time.current, messages: [])

    first_question = {
      prompt: "どっちの気分？",
      options: [
        { id: "light", text: "あっさり" },
        { id: "rich", text: "こってり" }
      ]
    }

    render json: { session_id: session.uuid, **first_question }
  end

  def next_question
    session = Session.find_by!(uuid: params[:session_id])
    service = OpenaiChatService.new(session)
    questions = service.generate_next_questions
    render json: { next_questions: questions }
  end

  def ai_answer
    session = Session.find_by!(uuid: params[:session_id])
    service = OpenaiChatService.new(session)

    result_text = service.reply_to(params[:question])
    next_questions = service.generate_next_questions

    if next_questions.present?
      render json: { next_questions: next_questions }
    else
      # Flutter 側は String 前提で受け取る
      render json: { result: result_text }
    end
  end
end