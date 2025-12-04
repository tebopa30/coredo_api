class OpenaiChatService
  def initialize(session)
    @session = session
    @client  = OpenAI::Client.new
    @state   = @session.state.presence || {
      "turn_count"    => 0,
      "finished"      => false,
      "last_question" => nil
    }
    @messages = Array(@session.messages)
  end

  def reply_to(question, force_finish: false)
    # 1) 終了済みセッションなら即座に結果かエラーで返す（AIコールをしない）
    if @state["finished"]
      last_assistant = @messages.reverse.find do |m|
        k_role = m.is_a?(Hash) ? (m[:role] || m["role"]) : nil
        k_role == "assistant"
      end
  
      if last_assistant
        parsed = safe_parse_json(last_assistant.is_a?(Hash) ? (last_assistant[:content] || last_assistant["content"]) : nil)
        if parsed.is_a?(Hash) && parsed["result"].is_a?(Hash)
          return { "result" => add_result(parsed["result"]) }
        elsif parsed.is_a?(Hash) && parsed["dish"] # 古い形式に対応
          return { "result" => add_result(parsed) }
        end
      end
      return { "error" => "このセッションはすでに終了しています" }
    end
  
    # 2) キーの型差異に強くする（String/Symbol混在対策）
    last_ai_message = @messages.last
    last_question   = nil
  
    if last_ai_message
      role = last_ai_message.is_a?(Hash) ? (last_ai_message[:role] || last_ai_message["role"]) : nil
      if role == "assistant"
        content = last_ai_message[:content] || last_ai_message["content"]
        parsed_last = safe_parse_json(content) rescue nil
        if parsed_last.is_a?(Array) && parsed_last.first.is_a?(Hash)
          last_question = parsed_last.first["question"]
        end
      end
    end
  
    selected_option = question.to_s
    user_message    = last_question ? "「#{last_question}」に対して「#{selected_option}」を選んだよ" : selected_option
  
    @messages << { role: "user", content: user_message }
    @state["turn_count"] += 1
  
    # 3) 終了条件（force_finish 最優先）
    must_finish = !!force_finish || (@state["turn_count"] >= 5)
  
    if must_finish
      ai_payload = call_ai(messages_for_finish(@messages))
      parsed     = safe_parse_json(ai_payload)
      result     = parsed&.dig("result")
  
      unless result.is_a?(Hash)
        Rails.logger.warn("[AI RESULT MISSING] #{ai_payload}")
        # 絶対に継続へ戻さない：ここで終了フラグを立てて打ち切る
        @state["finished"] = true
        finalize_session!
        return { "error" => "AIが最終提案を返しませんでした" }
      end

      @messages << { role: "assistant", content: result.to_json }
      @state["finished"] = true
      finalize_session!
      return { "result" => result }
    end
  
    # 4) 継続時：AIが結論を返したら即終了（ループ防止）
    ai_payload = call_ai(messages_for_next(@messages))
    parsed     = safe_parse_json(ai_payload)
  
    if parsed.is_a?(Hash) && parsed["result"].is_a?(Hash)
      result = add_result(parsed["result"])

      @messages << { role: "assistant", content: result.to_json }
      @state["finished"] = true
      finalize_session!
      return { "result" => result }
    elsif parsed.is_a?(Array) && valid_question_array?(parsed)
      next_q = suppress_duplicate_question(parsed.first)
      @messages << { role: "assistant", content: [next_q].to_json }
      finalize_session!
      return { "next_questions" => [next_q] }
    else
      # 継続モードのフォールバック（finishモードではここに来ない）
      fallback_q = {
        "question" => "なるほど！ じゃあ次は～",
        "options"  => ["さっぱりした感じ", "こってりした感じ", "軽めに食べたい"]
      }
      @messages << { role: "assistant", content: [fallback_q].to_json }
      finalize_session!
      return { "next_questions" => [fallback_q] }
    end
  end

  def start_conversation
    prompt = <<~TEXT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気でフランクな会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。タメ口で、語尾は優しく、親しみやすい口調を心がけてください。
      ユーザーが今食べたい料理を一緒に探すための「最初の質問」を考えてください。
      
      - 質問は必ず1件だけ返してください。
      - 質問文は短く、ひとことで表現してください。
      - 選択肢は必ず3つ以上返してください。
      - 空配列は禁止です。
      - 選択肢には料理名を一切含めないこと。

      出力は必ず以下の形式のみで返してください。自由文は禁止です。
      [
        {
          "question": "質問文",
          "options": ["選択肢1", "選択肢2", "選択肢3"]
        }
      ]
    TEXT

    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        temperature: 0.3,
        messages: [{ role: "user", content: prompt }]
      }
    )

    raw = response.dig("choices", 0, "message", "content")
    Rails.logger.info("[AI RAW RESPONSE] #{raw}")

    first_questions = safe_parse_json(raw) || [{
      "question" => "今の気分を教えて",
      "options" => ["さっぱり", "こってり", "軽め"]
    }]

    @messages << { role: "assistant", content: first_questions.to_json }
    finalize_session!
    { "next_questions" => first_questions }
  end

  private

  # ★修正点: ここはAPIを呼ばず、メッセージ配列を返すだけにする
  def messages_for_finish(messages)
    system_prompt = <<~PROMPT
      十分に情報が集まりました。これ以上質問はせず、必ず以下のJSON形式で最終提案のみを返してください。
      会話の締めくくりとして最適な料理を一つ選んでください。
      
      出力形式:
      { "result": { "dish": "料理名", "subtype": "サブタイプ", "description": "料理の簡単な紹介" } }
    PROMPT

    # システムプロンプト + これまでの履歴 を返す
    [{ role: "system", content: system_prompt }] + messages
  end

  def messages_for_next(messages)
    system_prompt = <<~PROMPT
      あなたは20代の清楚な日本人女性として、ユーザーと親しい友人のような雰囲気でフランクな会話を進めるAIです。
      会話はすべて柔らかい日本語で行ってください。タメ口で、語尾は優しく、親しみやすい口調を心がけてください。
      ユーザーが今食べたい料理を探しています。
      
      現在はヒアリングの段階です。
      - ユーザーの回答を踏まえて、次の一問を投げかけてください。
      - 質問は「[{"question": "...", "options": [...]}]」の配列形式で返してください。
      - まだ結論(result)は出さないでください。
      
      会話履歴: #{messages.to_json}
    PROMPT

    [{ role: "system", content: system_prompt }] + messages
  end

  def call_ai(messages)
    response = @client.chat(
      parameters: {
        model: "gpt-4o-mini",
        temperature: 0.3,
        messages: messages
      }
    )
    response.dig("choices", 0, "message", "content").to_s
  end

  # --- ヘルパーメソッド群 (変更なし) ---

  def valid_question_array?(arr)
    arr.is_a?(Array) &&
      arr.first.is_a?(Hash) &&
      arr.first.key?("question") &&
      arr.first.key?("options")
  end

  def safe_parse_json(text)
    # コードブロック ```json ... ``` が含まれている場合の除去処理を入れておくと安全です
    text = text.gsub(/^```json\n?|```$/, '')
    JSON.parse(text)
  rescue JSON::ParserError
    nil
  end

  def finalize_session!
    @session.update!(
      messages: @messages,
      state: @state,
      finished_at: @state["finished"] ? Time.current : nil
    )
  end

  def suppress_duplicate_question(q)
    q_str = q["question"].to_s.strip
    if q_str == @state["last_question"]
      alt = { "question" => "もう少し教えてほしいな～", "options" => ["和食", "洋食", "中華"] }
      @state["last_question"] = alt["question"]
      alt
    else
      @state["last_question"] = q_str
      q
    end
  end

end