class ImageGenerationJob < ApplicationJob
  queue_as :default

  def perform(result_hash)
    dish    = result_hash["dish"].to_s
    subtype = result_hash["subtype"].to_s
    desc    = result_hash["description"].to_s

    # 翻訳API呼び出し
    dish_en = translate_dish_with_api(dish)

    # プロンプト生成
    desc_part = desc.present? ? " #{desc}." : ""
    prompt = if dish_en.blank?
      "A high-quality appetizing photo of a rich creamy dish, beautifully plated with fresh ingredients."
    else
      "A high-quality appetizing photo of #{dish_en}, beautifully plated with fresh ingredients."
    end

    Rails.logger.info("[IMAGE PROMPT] #{prompt}")

    # 画像生成API呼び出し
    begin
      response = OpenAI::Client.new.images.generate(
        parameters: {
          model: "gpt-image-1",
          prompt: prompt,
          size: "512x512"
        }
      )
      image_url = response.dig("data", 0, "url") || placeholder_image_url

      # DB更新（Sessionに保存）
      session = Session.find_by(uuid: result_hash["session_id"])
      if session
        session.update!(image_url: image_url)
        ActionCable.server.broadcast(
          "session_#{session.uuid}",
          { image_url: image_url }
        )
      end
    rescue => e
      Rails.logger.error("[IMAGE GENERATION ERROR] #{e.message}")
    end
  end

  private

  def placeholder_image_url
    "http://10.0.2.2:3000/default.png"
  end

  require "net/http"
  require "json"

  # Google翻訳APIを利用して dish を英語に翻訳
  def translate_dish_with_api(dish)
    uri = URI("https://translation.googleapis.com/language/translate/v2")
    req = Net::HTTP::Post.new(uri, { "Content-Type" => "application/json" })
    req.body = {
      q: dish,
      source: "ja",
      target: "en",
      format: "text",
      key: ENV["GOOGLE_TRANSLATE_API_KEY"]
    }.to_json

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    json = JSON.parse(res.body)
    json.dig("data", "translations", 0, "translatedText").presence || dish
  rescue => e
    Rails.logger.error("[TRANSLATION ERROR] #{e.message}")
    dish # フォールバック
  end
end
