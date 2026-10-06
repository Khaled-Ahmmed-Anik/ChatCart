require "test_helper"

class KnowledgeSourceRefreshTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @business = Business.create!(name: "Alpha", slug: "alpha-refresh", category: "retail")
  end

  test "product changes queue a business knowledge refresh" do
    assert_enqueued_with(job: SyncBusinessKnowledgeJob, args: [ @business.id ]) do
      @business.products.create!(name: "The Oud", price: 420, stock_quantity: 5)
    end
  end

  test "policy changes queue a business knowledge refresh" do
    policy = @business.create_business_policy!(delivery_time: "Two days")
    clear_enqueued_jobs

    assert_enqueued_with(job: SyncBusinessKnowledgeJob, args: [ @business.id ]) do
      policy.update!(delivery_time: "Three days")
    end
  end
end
