require 'logger'

class Cloner
  @logger = Logger.new($stdout)
  @logger.level = Logger::INFO

  def self.logger
    @logger
  end

  def self.clone(issue_id, duration, recurring_field_id)
    original_user = User.current
    admin_user = User.find_by(admin: true)
    User.current = admin_user

    original = Issue.find_by_id(issue_id)
    unless original
      logger.warn("Original issue not found Issue##{issue_id}")
      return
    end

    existing = IssueRelation.
      where(issue_from: original.id, relation_type: IssueRelation::TYPE_COPIED_TO).
      order(issue_to_id: :desc).
      limit(1).
      first

    if existing
      existing_issue = Issue.find_by_id(existing.issue_to)
      unless existing_issue
        logger.warn("Existing issue not found Issue##{existing.issue_to}")
        return
      end

      unless existing_issue.start_date <= duration.ago
        logger.info("Nothing to do for now: latest start_date = #{existing_issue.start_date} for Issue##{existing_issue.id}")
        return
      end
    else
      unless original.start_date <= duration.ago
        logger.info("Nothing to do for now: latest start_date = #{original.start_date} for Issue##{original.id}")
        return
      end
    end

    due_date = if original.due_date.present?
      issue_date = (original.start_date || original.created_on).to_date
      Date.today + (original.due_date - issue_date)
    end


    ActiveRecord::Base.transaction do
      copied_issue =Issue.new.copy_from(original, attachments: false)
      copied_issue.custom_field_values = copied_issue.custom_field_values.inject({}) do |h, v|
        h[v.custom_field_id] = v.custom_field_id == recurring_field_id ? nil : v.value
        h
      end
      copied_issue.save!
      copied_issue.reload
      copied_issue.start_date = Date.today
      copied_issue.due_date = due_date
      copied_issue.save!
      copied_issue.reload

      copied_issue.children.each do |child_issue|
        child_issue.start_date = Date.today
        child_issue.due_date = due_date
        child_issue.save!
      end

      logger.info("Issue:#{issue_id} copied to Issue:#{copied_issue.id}")
    end

    User.current = original_user
  end

  def self.duration(variant)
    case variant
    when 'Weekly' then 1.week
    when 'Monthly' then 1.month
    when 'Quarterly' then 3.months
    when 'Semiannually' then 6.months
    when 'Annually' then 1.year
    else nil
    end
  end
end
