class OpenaiChatService
  def initialize(session)
    @session = session
    @client = OpenAI::Client.new
  end

  def reply_to(question)
    messages = @session.messages + [
      { role: "user", content: question }
    ]
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo-16k",
        temperature: 0.3,
        messages: [
          { role: "system", content: "あなたはユーザーからの返答に対してさらに質問を数回深掘りし、回答を導き出すAIです。" }
        ] + messages
      }
    )
    answer = response.dig("choices", 0, "message", "content")
    @session.update!(
      messages: messages + [{ role: "assistant", content: answer }]
    )
    answer
  end

  def generate_next_questions
    prompt = "以下の会話履歴に基づいて、次に聞くべき質問を2つ生成してください。必ずJSON配列形式で返してください。\n\n#{@session.messages.to_json}"
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo-16k",
        temperature: 0.3,
        messages: [{ role: "user", content: prompt }]
      }
    )
    raw = response.dig("choices", 0, "message", "content")
    begin
      JSON.parse(raw) # => ["質問1", "質問2"]
    rescue JSON::ParserError
      raw.split(/\n+/) # フォールバック: 改行区切りで配列化
    end
  end
  
end