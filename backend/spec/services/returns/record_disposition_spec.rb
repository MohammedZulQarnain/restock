require "rails_helper"

RSpec.describe Returns::RecordDisposition do
  let!(:product) { Product.create!(name: "Keyboard", sku: "KEY-001", category: "Accessories") }
  let!(:return_record) { Return.create!(product: product, quantity: 3, reason: "other") }

  def inspect_return(condition: "good", functional_status: "working", issue_found: false)
    return_record.update!(status: "received", received_at: Time.current)
    inspection = return_record.inspections.create!(
      condition: condition,
      functional_status: functional_status,
      issue_found: issue_found,
      accessories_complete: true
    )
    inspection.complete!
    inspection
  end

  it "adds sellable stock only for an eligible restock disposition" do
    inspect_return
    service = described_class.new(return_record: return_record, disposition_type: "restock", reason: "Passed inspection")

    expect { service.call }.to change { Inventory.quantity_for(product.id, "sellable") }.from(0).to(3)
    expect(return_record.reload.status).to eq("completed")
    expect(InventoryMovement.where(return: return_record).count).to eq(1)
  end

  it "does not allow damaged goods to be restocked" do
    inspect_return(condition: "damaged", functional_status: "working")
    service = described_class.new(return_record: return_record, disposition_type: "restock", reason: "Attempt")

    expect { service.call }.to raise_error(described_class::InvalidWorkflow, /restock eligibility/)
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(0)
  end

  it "routes quarantine stock away from sellable inventory" do
    inspect_return(condition: "damaged", functional_status: "not_working", issue_found: true)
    service = described_class.new(return_record: return_record, disposition_type: "quarantine", reason: "Needs review")

    expect { service.call }.to change { Inventory.quantity_for(product.id, "quarantine") }.from(0).to(3)
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(0)
  end

  it "does not apply the disposition twice" do
    inspect_return
    described_class.new(return_record: return_record, disposition_type: "restock", reason: "Passed").call
    second_attempt = described_class.new(return_record: return_record, disposition_type: "restock", reason: "Passed")

    expect { second_attempt.call }.to raise_error(described_class::InvalidWorkflow)
    expect(Inventory.quantity_for(product.id, "sellable")).to eq(3)
    expect(InventoryMovement.where(return: return_record).count).to eq(1)
  end
end
