module Returns
  class RecordDisposition
    class InvalidWorkflow < StandardError; end

    def initialize(return_record:, disposition_type:, reason:, notes: nil)
      @return_record = return_record
      @disposition_type = disposition_type.to_s
      @reason = reason.to_s
      @notes = notes
    end

    def call
      raise InvalidWorkflow, "Unsupported disposition." unless Disposition::TYPES.include?(@disposition_type)
      raise InvalidWorkflow, "A disposition reason is required." if @reason.blank?

      ActiveRecord::Base.transaction do
        record = Return.lock.find(@return_record.id)
        raise InvalidWorkflow, "Return must be inspected before disposition." unless record.status == "inspected"

        inspection = record.inspections.where.not(inspected_at: nil).order(inspected_at: :desc).first
        raise InvalidWorkflow, "A completed inspection is required." unless inspection

        if @disposition_type == "restock" && !restock_eligible?(inspection)
          raise InvalidWorkflow, "This inspection does not meet the restock eligibility rules."
        end

        disposition = Disposition.create!(
          return: record,
          inspection: inspection,
          disposition_type: @disposition_type,
          reason: @reason,
          notes: @notes,
          decided_at: Time.current
        )

        bucket = inventory_bucket_for(@disposition_type)
        if bucket
          inventory = Inventory.lock.find_or_create_by!(product: record.product, bucket: bucket)
          inventory.update!(quantity: inventory.quantity + record.quantity)
          InventoryMovement.create!(
            product: record.product,
            inventory: inventory,
            return: record,
            movement_type: @disposition_type,
            quantity_delta: record.quantity,
            reason: @reason,
            idempotency_key: "return-disposition:#{record.id}"
          )
        end

        record.update!(status: "completed", completed_at: Time.current)
        AuditEvent.create!(
          return: record,
          event_type: "disposition_recorded",
          details: { disposition_type: @disposition_type, quantity: record.quantity, reason: @reason }
        )
        disposition
      end
    rescue ActiveRecord::RecordNotUnique
      raise InvalidWorkflow, "A disposition or inventory movement has already been recorded for this return."
    end

    private

    def restock_eligible?(inspection)
      !%w[damaged defective].include?(inspection.condition) &&
        inspection.functional_status == "working" &&
        !inspection.issue_found
    end

    def inventory_bucket_for(type)
      { "restock" => "sellable", "refurbish" => "refurbishment",
        "quarantine" => "quarantine", "scrap" => "scrapped" }.fetch(type)
    end
  end
end
