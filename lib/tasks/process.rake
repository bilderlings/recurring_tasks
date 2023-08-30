require File.dirname(__FILE__) + '/../cloner.rb'

namespace :recurring_tasks do
  desc 'Run recurring tasks creation'
  task exec: :environment do
    custom_field =  CustomField.where(name: "Recurring").first
    next unless custom_field

    fields = CustomValue.where('customized_type = "Issue" and custom_field_id = ? and value != "" and value is not null', custom_field.id)

    fields.each do |field|
      duration = Cloner.duration(field.value)
      return unless duration
      puts("Found Issue##{field.customized_id} with recurring = #{field.value}")
      Cloner.clone(field.customized_id, duration, custom_field.id)
    end
  end
end
