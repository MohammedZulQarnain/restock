require "rails_helper"

RSpec.describe Return, type: :model do
  let!(:product) { Product.create!(name: "Wireless Headphones", sku: "AUD-RETURN-001", category: "Audio") }

  it "generates a unique human-readable return number" do
    record = described_class.create!(product: product, quantity: 1, reason: "damaged")
    expect(record.return_number).to match(/\ARET-\d{8}-[A-F0-9]{6}\z/)
  end

  it "rejects non-positive quantities" do
    record = described_class.new(product: product, quantity: 0, reason: "damaged")
    expect(record).not_to be_valid
    expect(record.errors[:quantity]).not_to be_empty
  end

  it "rejects unsupported reasons" do
    record = described_class.new(product: product, quantity: 1, reason: "because")
    expect(record).not_to be_valid
  end

  it "does not allow a new return for an inactive product" do
    product.update!(active: false)
    record = described_class.new(product: product, quantity: 1, reason: "other")
    expect(record).not_to be_valid
  end
end
