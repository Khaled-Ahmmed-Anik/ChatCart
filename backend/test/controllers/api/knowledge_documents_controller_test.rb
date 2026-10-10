require "test_helper"

class Api::KnowledgeDocumentsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @business = Business.create!(name: "Alpha", slug: "alpha-knowledge", category: "retail")
    @other_business = Business.create!(name: "Beta", slug: "beta-knowledge", category: "retail")
    @owner_token = create_user(@business, "owner@alpha.test", "owner")
    @staff_token = create_user(@business, "staff@alpha.test", "sales_agent")
    @other_document = create_manual(@other_business, title: "Private", content: "Other tenant secret")
  end

  test "index returns only current business knowledge" do
    document = create_manual(@business, title: "Shipping", content: "Delivery takes two days")

    get api_knowledge_documents_path, headers: authorization(@owner_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [ document.id ], body.map { |item| item.fetch("id") }
    assert body.first.fetch("editable")
  end

  test "owner can create update and delete manual knowledge" do
    assert_difference -> { @business.knowledge_documents.count }, 1 do
      post api_knowledge_documents_path, params: {
        knowledge_document: { title: "Gift wrapping", content: "Gift wrapping is free", active: true }
      }, headers: authorization(@owner_token), as: :json
    end
    assert_response :created
    document = @business.knowledge_documents.find(JSON.parse(response.body).fetch("id"))
    assert_equal KnowledgeDocument.checksum_for(title: document.title, content: document.content, metadata: {}), document.checksum

    patch api_knowledge_document_path(document), params: {
      knowledge_document: { title: "Gift wrapping", content: "Gift wrapping costs 50 BDT", active: true }
    }, headers: authorization(@owner_token), as: :json
    assert_response :success
    assert_equal "Gift wrapping costs 50 BDT", document.reload.content

    delete api_knowledge_document_path(document), headers: authorization(@owner_token)
    assert_response :no_content
    assert_not KnowledgeDocument.exists?(document.id)
  end

  test "staff can read and preview but cannot change knowledge" do
    create_manual(@business, title: "Delivery", content: "We deliver inside Dhaka in two days")

    get preview_api_knowledge_documents_path, params: { query: "delivery Dhaka" }, headers: authorization(@staff_token)
    assert_response :success
    assert_equal "Delivery", JSON.parse(response.body).dig("results", 0, "citation", "title")

    post api_knowledge_documents_path, params: {
      knowledge_document: { title: "Forbidden", content: "Staff write", active: true }
    }, headers: authorization(@staff_token), as: :json
    assert_response :forbidden
  end

  test "manual knowledge endpoints cannot access another tenant" do
    patch api_knowledge_document_path(@other_document), params: {
      knowledge_document: { title: "Changed", content: "Changed", active: true }
    }, headers: authorization(@owner_token), as: :json

    assert_response :not_found
    assert_equal "Private", @other_document.reload.title
  end

  test "generated knowledge cannot be edited or deleted directly" do
    product = @business.products.create!(name: "The Oud", price: 420, stock_quantity: 5)
    document = BusinessKnowledgeIndexer.new(business: @business).sync_product(product)

    patch api_knowledge_document_path(document), params: {
      knowledge_document: { title: "Changed", content: "Changed", active: true }
    }, headers: authorization(@owner_token), as: :json
    assert_response :unprocessable_entity

    delete api_knowledge_document_path(document), headers: authorization(@owner_token)
    assert_response :unprocessable_entity
    assert KnowledgeDocument.exists?(document.id)
  end

  test "status summarizes indexing state without leaking content" do
    create_manual(@business, title: "Active", content: "Active fact")
    create_manual(@business, title: "Inactive", content: "Inactive fact", active: false)

    get status_api_knowledge_documents_path, headers: authorization(@owner_token)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body.fetch("total")
    assert_equal 1, body.fetch("active")
    assert_equal 1, body.fetch("inactive")
    assert_equal({ "manual" => 2 }, body.fetch("by_source"))
  end

  test "sync queues tenant knowledge indexing" do
    assert_enqueued_with(job: SyncBusinessKnowledgeJob, args: [ @business.id ]) do
      post sync_api_knowledge_documents_path, headers: authorization(@owner_token)
    end

    assert_response :accepted
  end

  test "preview requires a useful query" do
    get preview_api_knowledge_documents_path, headers: authorization(@owner_token)

    assert_response :unprocessable_entity
    assert_equal "Query is required", JSON.parse(response.body).fetch("error")
  end

  private

  def create_user(business, email, role)
    token, digest = User.issue_token
    business.users.create!(name: role.titleize, email: email, role: role, api_token_digest: digest)
    token
  end

  def create_manual(business, title:, content:, active: true)
    business.knowledge_documents.create!(
      source_type: "manual", title: title, content: content, metadata: {}, active: active,
      checksum: KnowledgeDocument.checksum_for(title: title, content: content, metadata: {})
    )
  end

  def authorization(token)
    { "Authorization" => "Bearer #{token}" }
  end
end
