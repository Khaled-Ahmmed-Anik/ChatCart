require "nokogiri"

class ProductImportPreview
  def initialize(business:, source_url:, fetcher: PublicProductPageFetcher.new)
    @business = business
    @source_url = source_url
    @fetcher = fetcher
  end

  def create!
    page = fetcher.fetch(source_url)
    data = extract_page(page)
    data["duplicate_product_id"] = duplicate_product_id(data, page.url)
    business.product_import_drafts.create!(source_url: page.url, extracted_data: data.compact)
  rescue StandardError => error
    business.product_import_drafts.create!(
      source_url: source_url, status: "failed", error: error.message, extracted_data: {}
    )
  end

  private

  attr_reader :business, :source_url, :fetcher

  def extract_page(page)
    document = Nokogiri::HTML(page.body)
    api_url = document.at_css('link[rel="alternate"][type="application/json"]')&.[]("href")
    api_data = api_url.present? ? JSON.parse(fetcher.fetch(api_url).body) : {}
    schema = product_schema(document)
    title = api_data.dig("title", "rendered") || schema["name"] || document.at_css("h1")&.text || document.title
    long_html = api_data.dig("content", "rendered") || schema["description"]
    short_html = api_data.dig("excerpt", "rendered") || document.at_css('meta[name="description"]')&.[]("content")

    {
      "name" => clean(title),
      "short_description" => clean(short_html),
      "description" => clean(long_html),
      "source_url" => page.url,
      "woo_commerce_product_id" => api_data["id"]&.to_s,
      "image_urls" => image_urls(document, schema),
      "category" => detect_combo?(api_data, title, long_html) ? "Combo" : nil,
      "product_type" => detect_combo?(api_data, title, long_html) ? "fixed_combo" : "standard",
      "tags" => Array(api_data["class_list"]).grep(/product_tag-/).map { |tag| tag.delete_prefix("product_tag-").tr("-", " ") }.join(", "),
      "variants" => variations(document),
      "warnings" => import_warnings(schema, document)
    }.compact
  end

  def product_schema(document)
    document.css('script[type="application/ld+json"]').filter_map do |node|
      JSON.parse(node.text)
    rescue JSON::ParserError
      nil
    end.flatten.find { |item| item.is_a?(Hash) && item["@type"].to_s.casecmp("Product").zero? } || {}
  end

  def variations(document)
    node = document.at_css("[data-product_variations]")
    return [] if node.blank?

    JSON.parse(CGI.unescapeHTML(node["data-product_variations"])).filter_map.with_index do |variation, index|
      attributes = variation.fetch("attributes", {}).values.compact
      price = variation["display_price"] || variation["display_regular_price"]
      next if price.blank?

      { "name" => attributes.join(" / ").presence || "Option #{index + 1}", "size" => attributes.first,
        "price" => price.to_s, "stock_quantity" => variation["max_qty"].to_i,
        "active" => variation.fetch("variation_is_active", true), "position" => index }
    end
  rescue JSON::ParserError
    []
  end

  def image_urls(document, schema)
    ([ schema["image"] ] + document.css('meta[property="og:image"]').map { |node| node["content"] }).flatten.compact.uniq.first(8)
  end

  def detect_combo?(api_data, title, content)
    text = [ title, content, *Array(api_data["class_list"]) ].join(" ").downcase
    text.match?(/\b(combo|bundle|gift set|collection)\b/)
  end

  def import_warnings(schema, document)
    warnings = []
    offers = Array.wrap(schema["offers"]).first.to_h
    warnings << "Price was not publicly available; enter and verify it before publishing." if offers["price"].blank?
    warnings << "Stock was not publicly available; enter and verify it before publishing." unless document.to_html.include?("instock")
    warnings
  end

  def clean(value)
    Nokogiri::HTML.fragment(value.to_s).text.squish.presence
  end

  def duplicate_product_id(data, final_url)
    relation = business.products.where(source_url: final_url)
    external_id = data["woo_commerce_product_id"].presence
    relation = relation.or(business.products.where(woo_commerce_product_id: external_id)) if external_id
    relation.pick(:id)
  end
end
