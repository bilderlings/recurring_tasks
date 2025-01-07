class Cloner
  def self.clone(issue_id, duration, recurring_field_id)
      original = Issue.find_by_id(issue_id)
      return unless original

      existing = IssueRelation.
        where(issue_from: original.id, relation_type: IssueRelation::TYPE_COPIED_TO).
        order(issue_to_id: :desc).
        limit(1).
        first

      if existing
        existing_issue = Issue.find_by_id(existing.issue_to)
        return unless existing_issue
        return unless existing_issue.start_date <= duration.ago
      else
        return unless original.start_date <= duration.ago
      end

      copy = self.clone_issue_with_children(original)
      copy.start_date = Time.now

      if original.due_date.present?
        issue_date = (original.start_date || original.created_on).to_date
        copy.due_date = copy.start_date + (original.due_date - issue_date)
      end

      copy.children.each do |child|
        child.start_date = Time.now

        if original.due_date.present?
          issue_date = (original.start_date || original.created_on).to_date
          child.due_date = child.start_date + (original.due_date - issue_date)
        end

        child.reload
        child.save!
      end

      copy.custom_field_values = copy.custom_field_values.inject({}) do |h, v|
        h[v.custom_field_id] = v.custom_field_id == recurring_field_id ? nil : v.value
        h
      end

      copy.reload
      copy.save!
      puts("Issue##{original.start_date} cloned to ##{copy.id}")
  end

  def self.clone_issue_with_children(original_issue)
      cloned_issue = Issue.new.copy_from(original_issue, { attachments: false, watchers: true })
      cloned_issue.parent_issue_id = original_issue.parent_issue_id
      cloned_issue.save!

      original_issue.children.each do |child_issue|
          cloned_child_issue = clone_issue_with_children(child_issue)
          cloned_child_issue.parent_issue_id = cloned_issue.id
          cloned_child_issue.reload
          cloned_child_issue.save!
      end

      cloned_issue
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
