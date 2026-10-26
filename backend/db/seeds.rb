# Safe, repeatable demo catalog. Do not use real customer information here.
products = [
  { name: "Wireless Headphones", sku: "AUD-DEMO-001", category: "Audio", description: "Over-ear wireless headphones" },
  { name: "Everyday Backpack", sku: "BAG-DEMO-001", category: "Accessories", description: "General-purpose backpack" },
  { name: "Desk Lamp", sku: "HOME-DEMO-001", category: "Home", description: "Adjustable LED desk lamp" },
  { name: "Cotton Hoodie", sku: "APP-DEMO-001", category: "Clothing", description: "Unisex cotton hoodie" }
]

products.each do |attributes|
  Product.find_or_create_by!(sku: attributes[:sku]) do |product|
    product.assign_attributes(attributes)
  end
end

products.each do |attributes|
  product = Product.find_by!(sku: attributes[:sku])
  Inventory::BUCKETS.each do |bucket|
    Inventory.find_or_create_by!(product: product, bucket: bucket) { |inventory| inventory.quantity = 0 }
  end
end

[
  { return_number: "RET-DEMO-0001", product: Product.find_by!(sku: "AUD-DEMO-001"), quantity: 1, reason: "damaged", status: "registered", order_reference: "ORDER-DEMO-1001" },
  { return_number: "RET-DEMO-0002", product: Product.find_by!(sku: "BAG-DEMO-001"), quantity: 2, reason: "unwanted", status: "received", order_reference: "ORDER-DEMO-1002", received_at: Time.current }
].each do |attributes|
  record = Return.find_or_create_by!(return_number: attributes[:return_number]) do |return_record|
    return_record.assign_attributes(attributes)
  end
  AuditEvent.find_or_create_by!(return: record, event_type: "seed_demo_record") do |event|
    event.details = { seeded: true, return_number: record.return_number }
  end
end

puts "ReStock demo catalog and sample returns are ready."


# Create the first administrator only when credentials are explicitly configured.
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  admin = User.find_or_initialize_by(email: ENV.fetch("ADMIN_EMAIL").downcase.strip)
  if admin.new_record?
    admin.password = ENV.fetch("ADMIN_PASSWORD")
    admin.role = "admin"
    admin.save!
  end
end
