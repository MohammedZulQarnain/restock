require "rails_helper"

RSpec.describe Product, type: :model do
  subject(:product) do
    described_class.new(
      name: "Wireless Headphones",
      sku: "AUD-SONY-001",
      category: "Audio"
    )
  end

  describe "validations" do
    it "is valid with valid attributes" do
      expect(product).to be_valid
    end

    it "requires a name" do
      product.name = nil

      expect(product).not_to be_valid
      expect(product.errors[:name]).to include("can't be blank")
    end

    it "requires a SKU" do
      product.sku = nil

      expect(product).not_to be_valid
      expect(product.errors[:sku]).to include("can't be blank")
    end

    it "requires a category" do
      product.category = nil

      expect(product).not_to be_valid
      expect(product.errors[:category]).to include("can't be blank")
    end

    it "requires a unique SKU" do
      product.save!
      duplicate = described_class.new(
        name: "Another Headphones",
        sku: product.sku,
        category: "Audio"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sku]).to include("has already been taken")
    end
  end
end