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
    last_ai_message = @session.messages.last
    last_question = nil

    if last_ai_message && last_ai_message["role"] == "assistant"
      parsed_last = safe_parse_json(last_ai_message["content"]) rescue nil
      if parsed_last.is_a?(Array) && parsed_last.first.is_a?(Hash)
        last_question = parsed_last.first["question"]
      end
    end

    selected_option = question.to_s
    user_message = last_question ? "「#{last_question}」に対して「#{selected_option}」を選んだよ" : selected_option

    messages = Array(@session.messages) + [{ role: "user", content: user_message }]
    @state["turn_count"] += 1

    # 修正後の終了条件
    must_finish = (@state["turn_count"] >= 3)
    
    if must_finish
      ai_payload = call_ai(messages_for_finish(messages))
      parsed     = safe_parse_json(ai_payload)
    
      result = parsed&.dig("result").is_a?(Hash) ? parsed["result"] : {}
      result["dish"] ||= "おすすめの一品"
      result["subtype"] ||= "ジャンル未指定"
      result["description"] ||= "なるほど！ じゃあ次は～"
    
      result_with_image = add_image_to_result(result)
      persist!(messages, result_with_image.to_json)
      @state["finished"] = true
      return { "result" => result_with_image }
    end

    ai_payload = call_ai(messages_for_next(messages))
    parsed     = safe_parse_json(ai_payload)

    if parsed.is_a?(Hash) && parsed["result"].is_a?(Hash)
      if @state["turn_count"] < 3
        next_q = {
          "question" => "なるほど！ じゃあ次は～",
          "options" => ["さっぱり", "こってり", "軽め"]
        }
        persist!(messages, [next_q].to_json)
        return { "next_questions" => [next_q] }
      else
        result_with_image = add_image_to_result(parsed["result"])
        persist!(messages, result_with_image.to_json)
        @state["finished"] = true
        return { "result" => result_with_image }
      end
    elsif parsed.is_a?(Array) && valid_question_array?(parsed)
      next_q = suppress_duplicate_question(parsed.first)
      persist!(messages, [next_q].to_json)
      return { "next_questions" => [next_q] }
    else
      fallback_q = {
        "question" => "なるほど～ じゃあ次は～",
        "options" => ["さっぱりした感じ", "こってりした感じ", "軽めに食べたい"]
      }
      persist!(messages, [fallback_q].to_json)
      return { "next_questions" => [fallback_q] }
    end
  end

  def generate_next_questions
    prompt = <<~TEXT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気でフランクな会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。語尾は優しく、親しみやすい口調を心がけてください。

      ユーザーが今食べたい料理を一緒に探すための最初の質問を考えてください。
      質問はひとことで表現し、各質問に対して3つ以上の選択肢を3回以上示してください。空配列は禁止です。
      同じ質問を繰り返さないこと。
      選択肢には料理名を一切含めないこと。

      ★追記: 最終提案では必ずジャンル内のサブタイプ（例: ラーメンなら豚骨・醤油・味噌など）まで絞り込んでください。

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
        temperature: 0.3,
        messages: [{ role: "user", content: prompt }]
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    Rails.logger.info("[AI RAW RESPONSE] #{raw}")

    JSON.parse(raw) rescue [{ "question" => "あなたの好きなものを教えて", "options" => [] }]
  end

  def suppress_duplicate_question(q)
    q_str = q["question"].to_s.strip
    if q_str == @state["last_question"]
      alt = { "question" => "もう少し教えてほしいな～", "options" => ["さっぱり", "こってり", "軽め"] }
      @state["last_question"] = alt["question"]
      alt
    else
      @state["last_question"] = q_str
      q
    end
  end

  private

  def valid_question_array?(arr)
    arr.is_a?(Array) &&
      arr.first.is_a?(Hash) &&
      arr.first.key?("question") &&
      arr.first.key?("options") &&
      arr.first["question"].is_a?(String) &&
      arr.first["options"].is_a?(Array) &&
      arr.first["options"].any?
  end
  
  def safe_parse_json(text)
    JSON.parse(text)
  rescue JSON::ParserError
    nil
  end
  def persist!(messages, assistant_content)
    new_messages = messages + [{ role: "assistant", content: assistant_content }]
    @session.update!(messages: new_messages, state: @state)
  end

  def call_ai(messages)
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo-16k",
        temperature: 0.3,
        messages: messages
      }
    )
    response.dig("choices", 0, "message", "content").to_s
  end
  
  def messages_for_next(messages)
    system_prompt = <<~PROMPT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気でフランクな会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。語尾は優しく、親しみやすい口調を心がけてください。

      ユーザーが今食べたい料理を一緒に探すことが目的です。
      ユーザーの「今の気分」や「食の傾向」を短い一問で尋ね、選択肢を3つ以上示してください。空配列は禁止です。
      同じ質問を繰り返さないこと。
      十分に情報が集まったら、料理名を含めた最終提案を行ってください。

      ★最終提案では必ずジャンル内のサブタイプまで絞り込んでください。

      出力は以下のいずれかのみ。自由文は禁止。
      # { "result": { "dish": "料理名", "subtype": "サブタイプ", "description": "料理の簡単な紹介" } }
      # [ { "question": "質問文", "options": ["選択肢1", "選択肢2", "選択肢3"] } ]

      会話履歴: #{@session.messages.to_json}
    PROMPT

    [{ role: "system", content: system_prompt }] + messages
  end

  def messages_for_finish(messages)
    system_prompt = <<~PROMPT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気でフランクな会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。語尾は優しく、親しみやすい口調を心がけてください。

      十分に情報が集まりました。これ以上の質問は行わず、必ず最終提案のみを返してください。
      ★重要: 出力する料理は必ず具体的なジャンルとサブタイプを含めてください。
      例: ラーメンなら「豚骨ラーメン」「醤油ラーメン」、サブタイプとはラーメンでいうと「豚骨」や「醤油」のこと。

      出力は以下のみ。自由文は禁止。
      # { "result": { "dish": "料理名", "subtype": "サブタイプ", "description": "料理の簡単な紹介" } }

      会話履歴: #{@session.messages.to_json}
    PROMPT

    [{ role: "system", content: system_prompt }] + messages
  end

  # --- 画像生成を統合するメソッド ---
  def add_image_to_result(result_hash)
    dish = result_hash["dish"].to_s.strip
    subtype = result_hash["subtype"].to_s.strip
    description = result_hash["description"].to_s.strip

    image_url = generate_image_url(dish: dish, subtype: subtype, description: description)
    result_hash.merge("image_url" => image_url)
  end

  def generate_image_url(dish:, subtype:, description:)
    prompt = "#{dish}（#{subtype}）: #{description}"
    Rails.logger.info("[IMAGE PROMPT] #{prompt}")

    response = @client.images.generate(
      parameters: {
        prompt: prompt,
        size: "512x512",
        response_format: "url"
      }
    )

    response.dig("data", 0, "url") || placeholder_image_url
  rescue => e
    Rails.logger.warn("[IMAGE GENERATION ERROR] #{e}")
    placeholder_image_url
  end

  def placeholder_image_url
    "https://your-cdn.com/images/default.jpg"
  end
end