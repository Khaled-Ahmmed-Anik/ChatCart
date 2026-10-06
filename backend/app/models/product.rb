class Product < ApplicationRecord
  belongs_to :business, default: -> { Business.default }
  has_many :product_variants, -> { order(:position, :id) }, dependent: :destroy
  has_many :combo_items, -> { order(:position, :id) }, foreign_key: :combo_product_id,
    dependent: :destroy, inverse_of: :combo_product
  has_many :component_products, through: :combo_items, source: :component_product
  has_many :included_in_combo_items, class_name: "ComboItem", foreign_key: :component_product_id,
    dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error
  has_many :pending_orders, dependent: :restrict_with_error
  accepts_nested_attributes_for :product_variants, allow_destroy: true
  accepts_nested_attributes_for :combo_items, allow_destroy: true

  after_commit :refresh_business_knowledge

  scope :active, -> { where(active: true) }
  scope :available_for_sale, -> { active.where(archived_at: nil) }
  scope :in_stock, -> { where("stock_quantity > 0") }

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :product_type, inclusion: { in: %w[standard fixed_combo configurable_combo] }
  validates :stock_strategy, inclusion: { in: %w[independent component_derived manual] }

  def available_for_quantity?(requested_quantity)
    return product_variants.available.any? { |variant| variant.available_for_quantity?(requested_quantity) } if product_variants.any?

    requested_quantity.to_i.positive? && active? && stock_quantity >= requested_quantity.to_i
  end

  def available_variants
    product_variants.available
  end

  def starting_price
    available_variants.minimum(:price) || price
  end

  def total_available_stock
    return component_derived_stock if combo? && stock_strategy == "component_derived"

    product_variants.any? ? available_variants.sum(:stock_quantity) : stock_quantity
  end

  def combo?
    product_type.in?(%w[fixed_combo configurable_combo])
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(active: false, archived_at: Time.current)
  end

  def deletable?
    order_items.none? && pending_orders.none? && included_in_combo_items.none?
  end

  def searchable_names
    [ name, *aliases ].filter_map(&:presence).uniq
  end

  def component_snapshot
    combo_items.includes(:component_product).map do |item|
      { "product_id" => item.component_product_id, "name" => item.component_product.name,
        "quantity" => item.quantity, "selection_group" => item.selection_group }
    end
  end

  private

  def refresh_business_knowledge
    SyncBusinessKnowledgeJob.perform_later(business_id)
  end

  def component_derived_stock
    required_items = combo_items.includes(component_product: :product_variants).select(&:required?)
    return 0 if required_items.empty?

    required_items.map { |item| item.component_product.total_available_stock / item.quantity }.min
  end
end
