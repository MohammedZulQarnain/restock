class Api::V1::ReturnsController < ApplicationController
  before_action :set_return, only: %i[show receive start_inspection create_inspection complete_inspection disposition timeline]
  before_action -> { authorize_roles!("admin", "warehouse_operator") }, only: %i[create receive]
  before_action -> { authorize_roles!("admin", "inspector") }, only: %i[start_inspection create_inspection complete_inspection disposition]

  def index
    records = Return.includes(:product, :disposition).recent_first
    records = records.where(status: params[:status]) if params[:status].present?
    records = records.where(product_id: params[:product_id]) if params[:product_id].present?
    records = records.where(reason: params[:reason]) if params[:reason].present?
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      records = records.joins(:product).where(
        "returns.return_number ILIKE :term OR products.sku ILIKE :term OR products.name ILIKE :term",
        term: term
      )
    end
    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = [[params.fetch(:per_page, 20).to_i, 1].max, 100].min
    total = records.count
    render json: { data: records.offset((page - 1) * per_page).limit(per_page).map { |record| serialize_return(record) },
                   meta: { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil } }
  end

  def show
    render json: { data: serialize_return(@return_record) }
  end

  def create
    record = Return.new(return_params)
    if record.save
      AuditEvent.create!(return: record, event_type: "return_registered",
                         details: { return_number: record.return_number, quantity: record.quantity })
      render json: { data: serialize_return(record) }, status: :created
    else
      render_validation_error(record)
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { error: { code: "CONFLICT", message: "The return could not be registered because of a duplicate reference." } }, status: :conflict
  end

  def receive
    unless @return_record.status == "registered"
      return render_workflow_error("Only registered returns can be received.")
    end

    ActiveRecord::Base.transaction do
      @return_record.update!(status: "received", received_at: Time.current)
      AuditEvent.create!(return: @return_record, event_type: "return_received", details: {})
    end
    render json: { data: serialize_return(@return_record.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def start_inspection
    unless @return_record.status == "received"
      return render_workflow_error("Only received returns can enter inspection.")
    end

    @return_record.update!(status: "inspection_in_progress")
    AuditEvent.create!(return: @return_record, event_type: "inspection_started", details: {})
    render json: { data: serialize_return(@return_record) }
  end

  def create_inspection
    unless %w[received inspection_in_progress].include?(@return_record.status)
      return render_workflow_error("The return must be received before inspection.")
    end

    inspection = @return_record.inspections.new(inspection_params)
    if inspection.save
      render json: { data: inspection.as_json }, status: :created
    else
      render_validation_error(inspection)
    end
  end

  def complete_inspection
    inspection = @return_record.inspections.find(params[:inspection_id])
    inspection.complete!
    render json: { data: serialize_return(@return_record.reload) }
  rescue ActiveRecord::RecordNotFound
    render json: { error: { code: "NOT_FOUND", message: "Inspection not found for this return." } }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def disposition
    result = Returns::RecordDisposition.new(
      return_record: @return_record,
      disposition_type: params.require(:disposition).fetch(:disposition_type),
      reason: params.require(:disposition).fetch(:reason),
      notes: params[:disposition][:notes]
    ).call
    render json: { data: result.as_json }, status: :created
  rescue Returns::RecordDisposition::InvalidWorkflow, KeyError, ActionController::ParameterMissing => e
    render json: { error: { code: "INVALID_WORKFLOW", message: e.message } }, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    render_validation_error(e.record)
  end

  def timeline
    events = @return_record.audit_events.order(:created_at)
    render json: { data: events.as_json }
  end

  private

  def set_return
    @return_record = Return.includes(:product, :inspections, :disposition).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: { code: "NOT_FOUND", message: "Return not found." } }, status: :not_found
  end

  def return_params
    params.require(:return).permit(:product_id, :quantity, :order_reference, :reason, :customer_notes)
  end

  def inspection_params
    params.require(:inspection).permit(:condition, :functional_status, :accessories_complete,
                                       :issue_found, :damage_notes, :notes)
  end

  def serialize_return(record)
    record.as_json(include: { product: { only: %i[id name sku category] }, disposition: {} },
                   except: %i[updated_at])
  end

  def render_validation_error(record)
    render json: { error: { code: "VALIDATION_FAILED", message: "The request contains invalid data.",
                            details: record.errors.to_hash } }, status: :unprocessable_entity
  end

  def render_workflow_error(message)
    render json: { error: { code: "INVALID_WORKFLOW", message: message } }, status: :conflict
  end
end
