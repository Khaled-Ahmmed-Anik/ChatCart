class AddSalesObjectionPolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :business_policies, :authenticity_statement, :text
    add_column :business_policies, :discount_policy, :text
    add_column :business_policies, :trial_policy, :text
    add_column :business_policies, :trust_information, :text
    add_column :business_policies, :bulk_order_policy, :text
  end
end
