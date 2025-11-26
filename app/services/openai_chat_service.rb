class OpenaiChatService
  def initialize(session)
    @session = session
    @client = OpenAI::Client.new
  end

  def reply_to(question)
    messages = @session.messages + [{ role: "user", content: question }]
  
    system_prompt = <<~PROMPT
      あなたはユーザーと友人のような姿勢で会話を進めるAIです。
      様々な一言質問を2～3択で数回行い、好みや条件を十分に理解したら料理を提案してください。
      料理を提案する際は「finish」を呼び出すべきタイミングです。
      必ず料理名を含めた最終回答を返し、その後は画像生成に進みます。
  
      会話履歴: #{@session.messages.to_json}
    PROMPT
  
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo-16k",
        temperature: 0.3,
        messages: [{ role: "system", content: system_prompt }] + messages
      }
    )
  
    answer = response.dig("choices", 0, "message", "content")
  
    # 返却を必ず String に統一
    answer_str = answer.is_a?(String) ? answer : answer.to_json
  
    @session.update!(
      messages: messages + [{ role: "assistant", content: answer_str }]
    )
    answer_str
  end

  def generate_next_questions
    prompt = "以下の会話履歴に基づいて、好みや条件を理解し、答えを導き出すために様々な一言質問で2～3択で生成してください。"
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