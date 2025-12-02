class ImageGenerationService
  def self.add_image_to_result(result_hash)
    dish    = result_hash["dish"].to_s
    subtype = result_hash["subtype"].to_s
    desc    = result_hash["description"].to_s

    # 翻訳と画像生成を非同期ジョブに委譲
    ImageGenerationJob.perform_later(result_hash)

    # 非同期なので即座に image_url は返せない
    result_hash.merge("image_url" => nil)
  end
end
