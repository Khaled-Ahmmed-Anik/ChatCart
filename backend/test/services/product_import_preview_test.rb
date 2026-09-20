require "test_helper"

class ProductImportPreviewTest < ActiveSupport::TestCase
  FakeFetcher = Struct.new(:responses) do
    def fetch(url)
      body = responses.fetch(url)
      PublicProductPageFetcher::Response.new(url: url, body: body, content_type: "text/html")
    end
  end

  test "creates a review draft and only creates an inactive product after approval" do
    business = Business.create!(name: "Import Shop", slug: "import-shop")
    url = "https://shop.example/product/combo"
    api_url = "https://shop.example/wp-json/wp/v2/product/10"
    html = <<~HTML
      <html><head><link rel="alternate" type="application/json" href="#{api_url}"></head></html>
    HTML
    api = {
      id: 10, title: { rendered: "Combo for Her" }, excerpt: { rendered: "Three fragrances." },
      content: { rendered: "Includes The Blush, The Desire, and The Party." },
      class_list: %w[product product_cat-combo-packages product_tag-gift-for-her]
    }.to_json
    draft = ProductImportPreview.new(
      business: business, source_url: url, fetcher: FakeFetcher.new({ url => html, api_url => api })
    ).create!

    assert_equal "pending_review", draft.status
    assert_equal "Combo for Her", draft.extracted_data["name"]
    assert_equal "fixed_combo", draft.extracted_data["product_type"]
    assert_empty business.products

    product = ProductImportApprover.new(draft: draft).approve!
    assert_not product.active?
    assert_equal url, product.source_url
    assert_equal "approved", draft.reload.status
  end
end
