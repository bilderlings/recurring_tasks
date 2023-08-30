class Cloner
    def self.clone(issue_id, duration, recurring_field_id)
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

        copy = Issue.new.copy_from(original, { :attachments => false, :watchers => true })
        copy.start_date = Time.now

        if original.due_date.present?
          issue_date = (original.start_date || original.created_on).to_date
          copy.due_date = copy.start_date + (original.due_date - issue_date)
        end

        original.children.each do |child|
          child.start_date = Time.now

          if original.due_date.present?
            issue_date = (original.start_date || original.created_on).to_date
            child.due_date = child.start_date + (original.due_date - issue_date)
          end

          child.save!
        end

        copy.custom_field_values = copy.custom_field_values.inject({}) do |h, v|
          h[v.custom_field_id] = v.custom_field_id == recurring_field_id ? nil : v.value
          h
        end

        copy.save!
        puts("Issue##{original.start_date} cloned to ##{copy.id}")
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
