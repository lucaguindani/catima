module Loggable
  extend ActiveSupport::Concern

  attr_accessor :additional_logs

  module ClassMethods
    def create_and_log(attr=nil, author:, catalog:, additional_logs: nil)
      object = new(attr)
      object.save_and_log(author: author, catalog: catalog, additional_logs: additional_logs)
      object
    end

    def create_and_log!(attr=nil, author:, catalog:, additional_logs: nil)
      object = new(attr)
      object.save_and_log!(author: author, catalog: catalog, additional_logs: additional_logs)
      object
    end
  end

  def save_and_log(author:, catalog:, additional_logs: nil)
    action = new_record? ? "CREATE" : "UPDATE"
    return unless save

    self.additional_logs = additional_logs
    create_log(author, catalog, action) if relevant_changes.any?
    self
  end

  def save_and_log!(author:, catalog:, additional_logs: nil)
    save_and_log(author: author, catalog: catalog, additional_logs: additional_logs) || raise(ActiveRecord::RecordInvalid, self)
  end

  def update_and_log(attr, author:, catalog:, additional_logs: nil)
    assign_attributes(attr)
    save_and_log(author: author, catalog: catalog, additional_logs: additional_logs)
  end

  def update_and_log!(attr, author:, catalog:, additional_logs: nil)
    update_and_log(attr, author: author, catalog: catalog, additional_logs: additional_logs) || raise(ActiveRecord::RecordInvalid, self)
  end

  def destroy_and_log(author:, catalog:, additional_logs: nil)
    return unless destroy

    self.additional_logs = additional_logs
    create_log(author, catalog, "DELETE")
    self
  end

  def destroy_and_log!(author:, catalog:, additional_logs: nil)
    destroy_and_log(author: author, catalog: catalog, additional_logs: additional_logs) || raise(ActiveRecord::RecordInvalid, self)
  end

  private

  def relevant_changes
    without_blank_recursive(saved_changes.except(:created_at, :updated_at, :id).merge(additional_logs || {}))
  end

  def without_blank_recursive(relevant_changes)
    changes = {}
    relevant_changes.each do |k, values|
      if values.is_a?(Hash)
        data = without_blank_recursive(values)
        changes.store(k, data) unless data.empty?
      elsif values.first.present? || values.last.present? || values.last.is_a?(FalseClass)
        changes.store(k, values) if values.one? || values.uniq.many?
      end
    end
    changes
  end

  def create_log(author, catalog, action)
    EntryLog.create!(
      subject: self,
      catalog: catalog,
      author_id: author&.id,
      record_changes: relevant_changes,
      action: action
    )
  end
end
