class OpenaiChatService
  def initialize(session)
    @session = session
    @client  = OpenAI::Client.new

    @state = @session.state.presence || {
      "turn_count"    => 0,
      "finished"      => false,
      "last_question" => nil,
      "phase"         => "fixed",   # fixed → ai
      "mode"          => nil,       # meal / travel / play / future
      "answers"       => {}
    }

    @messages = Array(@session.messages)
  end

  # -------------------------
  #  Start conversation
  # -------------------------
  def start_conversation(mode:)
    @state["mode"] = mode
    @state["phase"] = "fixed"
    @state["answers"] = {}

    first_q = first_question_for(mode)

    @messages << { role: "assistant", content: [first_q].to_json }
    finalize_session!
    { "next_questions" => [first_q] }
  end

  # -------------------------
  #  Reply
  # -------------------------
  def reply_to(question, force_finish: false)
    return handle_finished_session if @state["finished"]

    mode = @state["mode"]

    case mode
    when "meal"   then reply_meal(question, force_finish: force_finish)
    when "travel" then reply_travel(question, force_finish: force_finish)
    when "play"   then reply_play(question, force_finish: force_finish)
    when "gift"   then reply_gift(question, force_finish: force_finish) 
    else
      { "error" => "Unknown mode: #{mode}" }
    end
  end

  # ============================================================
  #  固定質問フェーズ（modeごとに2問）
  # ============================================================

  # ---------- 食事 ----------
  def reply_meal(selected, force_finish: false)
    case @state["phase"]
    when "fixed" then handle_meal_fixed(selected)
    else handle_ai_phase(selected, force_finish: force_finish)
    end
  end

  def handle_meal_fixed(selected)
    last_q = last_question_text

    if last_q.include?("何系")
      @state["answers"]["genre"] = selected

      next_q = {
        "question" => "メインになるものはどんな感じがいい？",
        "options"  => ["肉系", "魚介系", "野菜系", "その他"]
      }

      push_messages(selected, next_q)
      return { "next_questions" => [next_q] }

    elsif last_q.include?("メインになる")
      @state["answers"]["main"] = selected
      @state["phase"] = "ai"
      selected_text = selected.is_a?(Hash) ? selected["option_id"] : selected
      @messages << { role: "user", content: selected_text }
      return handle_ai_phase(selected, force_finish: false)
    end
  end

  # ---------- 旅行 ----------
  def reply_travel(selected, force_finish: false)
    case @state["phase"]
    when "fixed" then handle_travel_fixed(selected)
    else handle_ai_phase(selected, force_finish: force_finish)
    end
  end

  def handle_travel_fixed(selected)
    last_q = last_question_text

    if last_q.include?("どんなタイプ")
      @state["answers"]["travel_type"] = selected

      next_q = {
        "question" => "旅行の目的はどんな感じ？",
        "options"  => ["リラックス", "グルメ", "アクティビティ", "その他"]
      }

      push_messages(selected, next_q)
      return { "next_questions" => [next_q] }

    elsif last_q.include?("目的は")
      @state["answers"]["purpose"] = selected
      @state["phase"] = "ai"
      selected_text = selected.is_a?(Hash) ? selected["option_id"] : selected
      @messages << { role: "user", content: selected_text }
      return handle_ai_phase(selected, force_finish: false)
    end
  end

  # ---------- 遊び ----------
  def reply_play(selected, force_finish: false)
    case @state["phase"]
    when "fixed" then handle_play_fixed(selected)
    else handle_ai_phase(selected, force_finish: force_finish)
    end
  end

  def handle_play_fixed(selected)
    last_q = last_question_text

    if last_q.include?("どんな遊び")
      @state["answers"]["play_type"] = selected

      next_q = {
        "question" => "今日は屋内と屋外どっちがいい？",
        "options"  => ["屋内", "屋外", "どっちでも"]
      }

      push_messages(selected, next_q)
      return { "next_questions" => [next_q] }

    elsif last_q.include?("屋内と屋外")
      @state["answers"]["place"] = selected
      @state["phase"] = "ai"
      selected_text = selected.is_a?(Hash) ? selected["option_id"] : selected
      @messages << { role: "user", content: selected_text }
      return handle_ai_phase(selected, force_finish: false)
    end
  end

  def reply_gift(selected, force_finish: false)
    case @state["phase"]
    when "fixed" then handle_gift_fixed(selected)
    else handle_ai_phase(selected, force_finish: force_finish)
    end
  end
  
    # ---------- プレゼント ----------
  def handle_gift_fixed(selected)
    last_q = last_question_text
  
    if last_q.include?("誰に")
      @state["answers"]["target"] = selected
  
      next_q = {
        "question" => "予算はどれくらい？",
        "options"  => ["〜3000円", "〜5000円", "〜10000円", "それ以上"]
      }
  
      push_messages(selected, next_q)
      return { "next_questions" => [next_q] }
  
    elsif last_q.include?("予算")
      @state["answers"]["budget"] = selected
      @state["phase"] = "ai"
  
      selected_text = selected.is_a?(Hash) ? selected["option_id"] : selected
      @messages << { role: "user", content: selected_text }
  
      return handle_ai_phase(selected, force_finish: false)
    end
  end

  # ============================================================
  #  AIフェーズ（Q3〜最終提案）
  # ============================================================
  def handle_ai_phase(selected, force_finish:)
    last_q = last_question_text
    selected_text = selected.is_a?(Hash) ? selected["option_id"] : selected
    user_message = last_q ? "「#{last_q}」に対して「#{selected_text}」を選んだよ" : selected_text

    @messages << { role: "user", content: user_message }
    @state["turn_count"] += 1

    must_finish = force_finish || @state["turn_count"] >= 9

    if must_finish
      ai_payload = call_ai(messages_for_finish(@messages))
      parsed = safe_parse_json(ai_payload)
    
      # 統一フォーマットに対応
      raw_result = parsed
    
      unless raw_result.is_a?(Hash) && raw_result["title"] && raw_result["description"]
        @state["finished"] = true
        finalize_session!
        return { "error" => "AIが最終提案を返しませんでした" }
      end
    
      normalized = normalize_result(raw_result, @state["mode"])
    
      @messages << { role: "assistant", content: normalized.to_json }
      @state["finished"] = true
      finalize_session!
      return { "result" => normalized }
    end

    # 継続質問
    ai_payload = call_ai(messages_for_next(@messages))
    parsed = safe_parse_json(ai_payload)

    if parsed.is_a?(Array) && valid_question_array?(parsed)
      next_q = suppress_duplicate_question(parsed.first)
      @messages << { role: "assistant", content: [next_q].to_json }
      finalize_session!
      return { "next_questions" => [next_q] }
    end

    # fallback
    fallback_q = fallback_question_for(@state["mode"])
    @messages << { role: "assistant", content: [fallback_q].to_json }
    finalize_session!
    { "next_questions" => [fallback_q] }
  end

  def fallback_question_for(mode)
    case mode
    when "meal"
      {
        "question" => "今の気分に一番近いのはどれかな？",
        "options"  => ["さっぱり", "こってり", "軽め"]
      }
    when "travel"
      {
        "question" => "どんな雰囲気の旅がしたい？",
        "options"  => ["ゆったり", "アクティブ", "観光メイン"]
      }
    when "play"
      {
        "question" => "どんな遊び方がいい？",
        "options"  => ["まったり", "ワイワイ", "体を動かす"]
      }
    when "gift"
      {
        "question" => "相手が喜びそうなのはどんな感じ？",
        "options"  => ["実用的", "おしゃれ", "癒し系"]
      }
    else
      {
        "question" => "もう少し教えてほしいな〜",
        "options"  => ["これがいい", "まあまあかな", "ちょっと違うかも"]
      }
    end
  end

  # ============================================================
  #  プロンプト生成（modeごとに最適化）
  # ============================================================

  def messages_for_next(messages)
    mode = @state["mode"]

    system_prompt =
      case mode
      when "meal"   then prompt_meal_next
      when "travel" then prompt_travel_next
      when "play"   then prompt_play_next
      when "gift"   then prompt_gift_next
      end

    [{ role: "system", content: system_prompt }] + messages
  end

  def messages_for_finish(messages)
    mode = @state["mode"]

    system_prompt =
      case mode
      when "meal"   then prompt_meal_finish
      when "travel" then prompt_travel_finish
      when "play"   then prompt_play_finish
      when "gift"   then prompt_gift_finish
      end

    [{ role: "system", content: system_prompt }] + messages
  end

  # ============================================================
  #  プロンプト最適化（modeごと）
  # ============================================================

  # ---------- meal ----------
  def prompt_meal_next
    a = @state["answers"]
    <<~PROMPT
      あなたは優しい20代女性の友達として、タメ口で柔らかく話す。

      目的: 食事の好みを聞きながら、次の質問を1つだけ返す。

      これまでの選択:
      - ジャンル: #{a["genre"]}
      - メイン食材: #{a["main"]}

      制約:
      - 出力は必ず JSON 配列形式
      - 質問は1つ
      - options は3つ以上6つ以下
      - 食事を決めるために必要な情報（味の傾向、量、雰囲気、時間帯など）を深掘りする質問にすること
      - 抽象的すぎる質問は禁止（例: 「他に何かある？」など）
      - デザートや飲み物は質問に含めないこと
      - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
      - 同じ表現を繰り返さないこと

      出力例:
      [{ "question": "気分はどんな感じ？", "options": ["さっぱり", "がっつり", "軽め"] }]
    PROMPT
  end

  def prompt_meal_finish
    a = @state["answers"]
    <<~PROMPT
      目的: 食事の最終提案を1つだけ返す。

      これまでの選択:
      - ジャンル: #{a["genre"]}
      - メイン食材: #{a["main"]}

      制約:
      - 出力は必ず JSON
      - title と description を必ず含める
      - title は「具体的な料理名」（例: カレーライス、寿司、麻婆豆腐）
      - 抽象的な回答（例: 和食、肉料理、中華料理）は禁止
      - 一般名詞だけの回答（例: カレー、パスタ）はNG。必ず特徴を含めること
        （例: 「スパイス香るチキンカレー」「濃厚カルボナーラ」など）
      - description は優しいタメ口で短く
      - extra.raw には料理の特徴や理由など自由に入れてよい
      - デザートや飲み物は質問に含めないこと
      - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
      - 同じ表現を繰り返さないこと

    最終回答は必ず次の JSON 形式で返してください：

    {
      "title": "ユーザーに提案する具体的な料理名（例: カレーライス、寿司、麻婆豆腐）",
      "description": "提案の説明文。理由や魅力を簡潔に書く。",
      "extra": {
        "mode": "meal",
        "raw": {
          ... モード固有の追加情報を自由に入れてよい ...
        }
      }
    }

    重要：
    - title は必ず1行でわかりやすい名前にする
    - description は自然な文章にする
    - extra.raw のキーは自由だが、title と description は必須
    - JSON 以外の文章は書かない
    PROMPT
  end

  # ---------- travel ----------
  def prompt_travel_next
    a = @state["answers"]
    <<~PROMPT
      あなたは優しい20代女性の友達として、タメ口で柔らかく話す。

      目的: 旅行先の好みを聞きながら、次の質問を1つだけ返す。

      これまでの選択:
      - タイプ: #{a["travel_type"]}
      - 目的: #{a["purpose"]}

      制約:
      - JSON配列
      - 質問は1つ
      - optionsは3つ以上6つ以下
      - 国内旅行か国外旅行かを必ず聞くこと
      - ある程度の地方が絞れるような質問をすること
      - 旅行先を決めるために必要な情報（誰と行くか、雰囲気、興味のある旅先 など）を深掘りする質問にすること
      - 抽象的すぎる質問は禁止（例: 「他に何かある？」など）
      - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
      - 同じ表現を繰り返さないこと

    PROMPT
  end

  def prompt_travel_finish
    a = @state["answers"]
    <<~PROMPT
      目的: 旅行先の最終提案を1つ返す。
  
      これまでの選択:
      - タイプ: #{a["travel_type"]}
      - 目的: #{a["purpose"]}
  
      制約:
      - 出力は必ず JSON
      - title は「具体的な観光スポット名」（例: 清水寺、兼六園、美ら海水族館）
      - 都道府県名・市区町村名・地域名だけの回答は禁止（例: 京都、札幌、沖縄本島 など）
      - ある程度の地方が絞れるような質問をすること、必ず具体的なスポット名を提案すること
      - 抽象的な観光地（例: 温泉街、海辺、山エリア）はNG
      - 一般名詞だけの案（例: 寺、博物館、公園）はNG。必ず固有名詞や特徴を含めること
        （例: 「東大寺」「国立科学博物館」「代々木公園の噴水エリア」など）
      - description は優しいタメ口で短く
      - extra.raw にはスポット名や地域名など自由に入れてよい
      - 国内旅行か国外旅行かを必ず考慮すること
      - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
      - 同じ表現を繰り返さないこと
  
      最終回答は必ず次の JSON 形式で返してください：
  
      {
        "title": "ユーザーに提案する名前（旅行先のスポット名）",
        "description": "提案の説明文。理由や魅力を簡潔に書く。",
        "extra": {
          "mode": "travel",
          "raw": {
            ... モード固有の追加情報を自由に入れてよい ...
          }
        }
      }
  
      重要：
      - title は必ず1行でわかりやすい名前にする
      - description は自然な文章にする
      - JSON 以外の文章は書かない
    PROMPT
  end

  # ---------- play ----------
  def prompt_play_next
    a = @state["answers"]
    <<~PROMPT
      あなたは優しい20代女性の友達として、タメ口で柔らかく話す。

      目的: 遊びの好みを聞きながら、次の質問を1つ返す。

      これまでの選択:
      - 遊びタイプ: #{a["play_type"]}
      - 屋内外: #{a["place"]}

      制約:
      - JSON配列
      - 質問は1つ
      - optionsは3つ以上6つ以下
      - プレイ内容を決めるために必要な情報（誰と遊ぶか、時間帯、雰囲気、体力、静か/にぎやか など）を深掘りする質問にすること
      - 抽象的すぎる質問は禁止（例: 「他に何かある？」など）
      - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
      - 同じ表現を繰り返さないこと

    PROMPT
  end

  def prompt_play_finish
    a = @state["answers"]
    <<~PROMPT
      目的: 遊びの最終提案を1つ返す。
  
      これまでの選択:
      - 遊びタイプ: #{a["play_type"]}
      - 屋内外: #{a["place"]}
  
      制約:
      - 出力は必ず JSON
      - title は「具体的な遊び案」（例: ハイキング、陶芸体験、ボウリング）
      - 抽象的すぎる案（例: 外で遊ぶ、アクティビティ、レジャー）は禁止
      - 一般名詞だけの案（例: 散歩、買い物）はNG。必ず特徴や具体性を含めること
       （例: 「川沿いのライトアップ散歩」「アウトレットでのショッピングデート」など）
      - description は優しいタメ口で短く
      - extra.raw には遊びの種類やスタイルなど自由に入れてよい
      - 誰と遊ぶかを必ず考慮すること
      - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
      - 同じ表現を繰り返さないこと

  
      最終回答は必ず次の JSON 形式で返してください：
  
      {
        "title": "ユーザーに提案する名前（遊び案）",
        "description": "提案の説明文。理由や魅力を簡潔に書く。",
        "extra": {
          "mode": "play",
          "raw": {
            ... モード固有の追加情報を自由に入れてよい ...
          }
        }
      }
  
      重要：
      - title は必ず1行でわかりやすい名前にする
      - description は自然な文章にする
      - JSON 以外の文章は書かない
    PROMPT
  end

  # ---------- gift ----------
  def prompt_gift_next
    a = @state["answers"]
    <<~PROMPT
      あなたは優しい20代女性の友達として、タメ口で柔らかく話す。
  
      目的: プレゼントの好みを聞きながら、次の質問を1つだけ返す。
  
      これまでの選択:
      - 相手: #{a["target"]}
      - 予算: #{a["budget"]}
  
      制約:
      - JSON配列
      - 質問は1つ
      - optionsは3つ以上6つ以下
      - プレゼント選びに必要な情報（相手の好み、性格、用途、シーンなど）を深掘りする質問にすること
      - 抽象的すぎる質問は禁止（例: 「他に何かある？」など）
      - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
      - 同じ表現を繰り返さないこと

    PROMPT
  end

  def prompt_gift_finish
    a = @state["answers"]
    <<~PROMPT
      目的: プレゼントの最終提案を1つ返す。
  
      これまでの選択:
      - 相手: #{a["target"]}
      - 予算: #{a["budget"]}
  
      制約:
    - 出力は必ず JSON
    - title は「具体的なプレゼント名」（例: シルバーのネックレス、ハンドクリーム）
    - 抽象的なカテゴリ名（例: アクセサリー、雑貨、コスメ）は禁止
    - 一般名詞だけの回答（例: ネックレス、財布、マグカップ）はNG。必ず固有名詞や特徴を含めること
      （例: 「シルバーの月型ネックレス」「木製ハンドルのマグカップ」など）
    - 可能であればブランド名や素材やキャラクターなども含めて具体的にすること（例: LUSH のバスボムセット）
    - description は優しいタメ口で短く
    - extra.raw にはカテゴリや詳細など自由に入れてよい
    - 回答は毎回少し違う言い回しで、自然なバリエーションを持たせてください
    - 同じ表現を繰り返さないこと

      最終回答は必ず次の JSON 形式で返してください：
  
      {
        "title": "ユーザーに提案する名前（プレゼント名）",
        "description": "提案の説明文。理由や魅力を簡潔に書く。",
        "extra": {
          "mode": "gift",
          "raw": {
            ... モード固有の追加情報を自由に入れてよい ...
          }
        }
      }
  
      重要：
      - title は必ず1行でわかりやすい名前にする
      - description は自然な文章にする
      - JSON 以外の文章は書かない
    PROMPT
  end

  # ============================================================
  #  Utility
  # ============================================================

  def first_question_for(mode)
    case mode
    when "meal"
      { "question" => "まずはざっくり、何系のごはんが食べたい？",
        "options"  => ["和食", "洋食", "中華", "ラーメン", "その他"] }
    when "travel"
      { "question" => "どんなタイプの旅行がしたい？",
        "options"  => ["自然", "街歩き", "観光", "温泉", "アクティブ", "その他"] }
    when "play"
      { "question" => "どんな遊びがしたい気分？",
        "options"  => ["屋内でまったり", "外でアクティブ", "友達とワイワイ", "一人で楽しむ"] }
    when "gift"
      { "question" => "誰にプレゼントしたい？",
        "options"  => ["恋人", "友達", "家族", "自分", "子供", "その他"] }
    end
  end

  def last_question_text
    last_ai = @messages.reverse.find { |m| (m[:role] || m["role"]) == "assistant" }
    return nil unless last_ai

    parsed = safe_parse_json(last_ai[:content] || last_ai["content"])
    parsed&.first&.dig("question")
  end

  def push_messages(selected, next_q)
    selected_text = selected.is_a?(Hash) ? selected["option_id"] : selected
  
    @messages << { role: "user", content: selected_text }
    @messages << { role: "assistant", content: [next_q].to_json }
  
    @state["last_question"] = next_q["question"]
    @state["turn_count"] += 1
    finalize_session!
  end

  def call_ai(messages)
    response = @client.chat(
      parameters: {
        model: "gpt-4o",
        temperature: 0.8,
        top_p: 0.9,
        presence_penalty: 0.6,
        frequency_penalty: 0.4,
        messages: messages
      }
    )
    response.dig("choices", 0, "message", "content").to_s
  end

  def safe_parse_json(text)
    text = text.gsub(/^```json\n?|```$/, '')
    JSON.parse(text)
  rescue
    nil
  end

  def valid_question_array?(arr)
    arr.is_a?(Array) &&
      arr.first.is_a?(Hash) &&
      arr.first.key?("question") &&
      arr.first.key?("options")
  end

  def suppress_duplicate_question(q)
    q_str = q["question"].to_s.strip
    if q_str == @state["last_question"]
      alt = {
        "question" => "もう少し教えてほしいな〜",
        "options"  => ["A", "B", "C"]
      }
      @state["last_question"] = alt["question"]
      alt
    else
      @state["last_question"] = q_str
      q
    end
  end

  def finalize_session!
    @session.update!(
      messages: @messages,
      state: @state,
      finished_at: @state["finished"] ? Time.current : nil
    )
  end

  def handle_finished_session
    last_ai = @messages.reverse.find { |m| (m[:role] || m["role"]) == "assistant" }
    parsed = safe_parse_json(last_ai&.dig(:content))
  
    if parsed && parsed["title"] && parsed["description"]
      { "result" => parsed }
    else
      { "error" => "このセッションはすでに終了しています" }
    end
  end

  def normalize_result(raw, mode)
    title = raw["title"] || "おすすめが見つかったよ！"
    description = raw["description"] || "詳しい説明は後ほど追加予定です"
  
    {
      "title" => title,
      "description" => description,
      "extra" => {
        "mode" => mode,
        "raw" => raw
      }
    }
  end

end