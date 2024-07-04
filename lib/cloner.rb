class Cloner

  def self.clone(issue_id, duration, recurring_field_id)
    original_user = User.current
    admin_user = User.find_by(admin: true)
    User.current = admin_user

    original = Issue.find_by_id(issue_id)
    unless original
      puts("Original issue not found Issue##{issue_id}")
      return
    end

    existing = IssueRelation.
      where(:issue_from => original.id, :relation_type => IssueRelation::TYPE_COPIED_TO).
      order(issue_to_id: :desc).
      limit(1).
      first

    if existing
      existing_issue = Issue.find_by_id(existing.issue_to)
      unless existing_issue
        puts("Existing issue not found Issue##{existing.issue_to}")
        return
      end

      unless existing_issue.start_date <= duration.ago
        puts("Nothing to do for now: latest start_date = #{existing_issue.start_date} for Issue##{existing_issue.id}")
        return
      end
    else
      unless original.start_date <= duration.ago
        puts("Nothing to do for now: latest start_date = #{original.start_date} for Issue##{original.id}")
        return
      end
    end

    Issue.transaction do
      copy = self.clone_issue_with_children(original, recurring_field_id)

      puts("Issue##{original.id} cloned to ##{copy.id}")
    end

    User.current = original_user
  end

  def self.clone_issue_with_children(original_issue, recurring_field_id)
    cloned_issue = Issue.new.copy_from(original_issue, { :attachments => false, })
    cloned_issue.assigned_to_id = nil

    if original_issue.due_date.present?
      issue_date = (original_issue.start_date || original_issue.created_on).to_date
      cloned_issue.due_date = cloned_issue.start_date + (original_issue.due_date - issue_date)
    end

    cloned_issue.custom_field_values = cloned_issue.custom_field_values.inject({}) do |h, v|
      h[v.custom_field_id] = v.custom_field_id == recurring_field_id ? nil : v.value
      h
    end

    cloned_issue.children.each do |child_issue|
      child_issue.assigned_to_id = nil
    end


    cloned_issue.save!
    self.start_date_now(cloned_issue)

    cloned_issue
  end

  def self.start_date_now(issue)
    issue.reload
    issue.start_date = DateTime.now
    issue.save!

    issue.children.each do |child_issue|
      child_issue.start_date = DateTime.now
      child_issue.save!
    end
  end

  def self.duration(variant)
    case variant
    when 'Weekly'
      1.week
    when 'Monthly'
      1.month
    when 'Quarterly'
      3.months
    when 'Semiannually'
      6.months
    when 'Annually'
      1.year
    else
      nil
    end
  end


end
