class OpenaiChatService
  def initialize(session)
    @session = session
    @client  = OpenAI::Client.new
    @state   = @session.state.presence || {
      "turn_count"    => 0,
      "finished"      => false,
      "last_question" => nil
    }
  end

  def reply_to(question)
    messages = Array(@session.messages) + [{ role: "user", content: question.to_s }]
    @state["turn_count"] = @state["turn_count"].to_i + 1

    must_finish = (@state["turn_count"] >= 5) || @state["finished"] == true

    if must_finish
      ai_payload = call_ai(messages_for_finish(messages))
      parsed     = safe_parse_json(ai_payload)
      if parsed.is_a?(Hash) && parsed["result"].is_a?(Hash)
        persist!(messages, parsed.to_json)
        @state["finished"] = true
        return { "result" => parsed["result"] }
      else
        fallback_result = {
          "dish" => "おすすめの一品",
          "subtype" => "ジャンル未指定",
          "description" => "これまでの回答内容に基づく提案です。もう一度お好みを教えていただければ、より具体的にご提案できます。"
        }
        persist!(messages, fallback_result.to_json)
        @state["finished"] = true
        return { "result" => fallback_result }
      end
    end

    ai_payload = call_ai(messages_for_next(messages))
    parsed     = safe_parse_json(ai_payload)

    if parsed.is_a?(Hash) && parsed["result"].is_a?(Hash)
      persist!(messages, parsed.to_json)
      @state["finished"] = true
      return { "result" => parsed["result"] }
    elsif parsed.is_a?(Array) && valid_question_array?(parsed)
      next_q = suppress_duplicate_question(parsed.first)
      persist!(messages, [next_q].to_json)
      return { "next_questions" => [next_q] }
    else
      fallback_q = { "question" => "今の気分や食の傾向を教えてください", "options" => [] }
      persist!(messages, [fallback_q].to_json)
      return { "next_questions" => [fallback_q] }
    end
  end

  def generate_next_questions
    prompt = <<~TEXT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気で会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。語尾は優しく、親しみやすい口調を心がけてください。

      ユーザーが今食べたい料理を一緒に探すための最初の質問を考えてください。
      質問はひとことで表現し、各質問に対して3つ以上の選択肢を日本語で生成してください。
      選択肢には料理名を一切含めないこと。

      出力は必ず以下の形式のみで返してください。
      [
        {
          "question": "質問文",
          "options": ["選択肢1", "選択肢2", "選択肢3"]
        }
      ]
    TEXT

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo-16k",
        temperature: 0.7,
        messages: [{ role: "user", content: prompt }]
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    Rails.logger.info("[AI RAW RESPONSE] #{raw}")

    begin
      JSON.parse(raw)
    rescue JSON::ParserError
      [{ "question" => "食の好みを教えてください", "options" => [] }]
    end
  end

  private

  def messages_for_next(messages)
    system_prompt = <<~PROMPT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気で会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。語尾は優しく、親しみやすい口調を心がけてください。

      ユーザーが今食べたい料理を一緒に探すことが目的です。
      ユーザーの「今の気分」や「食の傾向」を短い一問で尋ね、選択肢を3つ以上示してください。
      十分に情報が集まったら、料理名を含めた最終提案を行ってください。

      ★追記: 最終提案では必ずジャンル内のサブタイプ（例: ラーメンなら豚骨・醤油・味噌など）まで絞り込んでください。

      出力は以下のいずれかのみを厳守してください。自由文は一切出力しないこと。
      # {
      #   "result": { "dish": "料理名", "subtype": "サブタイプ", "description": "料理の説明" }
      # }
      # [
      #   { "question": "質問文", "options": ["選択肢1", "選択肢2", "選択肢3"] }
      # ]

      会話履歴: #{@session.messages.to_json}
    PROMPT

    [{ role: "system", content: system_prompt }] + messages
  end

  def messages_for_finish(messages)
    system_prompt = <<~PROMPT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気で会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。語尾は優しく、親しみやすい口調を心がけてください。

      十分に情報が集まりました。これ以上の質問は行わず、必ず最終提案のみを返してください。

      ★追記: 提案は料理名だけでなく、ジャンル内のサブタイプ（例: ラーメンなら豚骨・醤油・味噌など）まで絞り込んでください。

      出力は以下の形式のみ。自由文は一切出力しないこと。
      # {
      #   "result": { "dish": "料理名", "subtype": "サブタイプ", "description": "料理の説明" }
      # }

      会話履歴: #{@session.messages.to_json}
    PROMPT

    [{ role: "system", content: system_prompt }] + messages
  end

  def call_ai(messages)
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo-16k",
        temperature: 0.7,
        messages: messages
      }
    )
    response.dig("choices", 0, "message", "content").to_s
  end

  def persist!(messages, assistant_content)
    new_messages = messages + [{ role: "assistant", content: assistant_content }]
    @session.update!(messages: new_messages, state: @state)
  end

  def safe_parse_json(text)
    JSON.parse(text)
  rescue JSON::ParserError
    nil
  end

  def valid_question_array?(arr)
    arr.is_a?(Array) && arr.first.is_a?(Hash) &&
      arr.first.key?("question") && arr.first.key?("options") &&
      arr.first["question"].is_a?(String) &&
      arr.first["options"].is_a?(Array)
  end

  def suppress_duplicate_question(q)
    q_str = q["question"].to_s.strip
    if q_str == @state["last_question"]
      alt = { "question" => "別の観点から、今の気分を教えてください", "options" => [] }
      @state["last_question"] = alt["question"]
      alt
    else
      @state["last_question"] = q_str
      q
    end
  end
end