module Sifter
  class Issue
    attr_reader :project, :url, :hash, :id, :number, :subject, :opened_by, :assigned_to, :status, :priority, :category, :comments, :date_created, :date_updated
    
    # Alternative names to subject.
    alias :title :subject
    alias :name :subject
    
    # Alternative names to opened_by.
    alias :created_by :opened_by
    
    def initialize(project, details) # :nodoc:
      @project, @hash = project, details
      details.each {|key, value| instance_variable_set(:"@#{key}", value)}
      
      if @category == ''
        @category = 'None'
      end
      
      @url = project.url + "/#{self.number}"
    end
    
    def body
      project.client.agent.get(self.url).at('div.description/p').inner_text
    end
    
    def update(updates)
      if updates.empty?
        return Sifter.detailed_return(project.client.detailed_return,
          :successful => true,
          :message => 'No updates or changes made.')
      end
      
      editable_attributes = [:status, :priority, :category, :assignee]
      
      if !(updates.keys - editable_attributes).empty?
        attributes_list = editable_attributes.collect {|attribute| attribute.to_s}.join(', ')
        
        return Sifter.detailed_return(project.client.detailed_return, 
                :successful => false, 
                :message => "You provided too many updates. Only the following are available for updating: #{attributes_list}.") 
      end
      
      issue_page = self.project.client.agent.get(self.url)
      update_form = issue_page.forms.first
      
      # Change the status value explicitly, since "opened" can mean either opened or reopened.
      if updates.keys.include?(:status)
        if updates[:status] == 'open' && (self.status == 'Closed' || self.status == 'Resolved')
          updates[:status] = 'reopened'
        end
        
        if updates[:status] == 'resolved' && self.status == 'Closed'          
          return Sifter.detailed_return(project.client.detailed_return,
                  :successful => false,
                  :message => 'You cannot change a closed issue to resolved.')
        end
        
        status_codes = {'1' => 'Open', '2' => 'Reopened', '3' => 'Resolved', '4' => 'Closed'}
        
        value = status_codes.to_a.find {|code, status| status.downcase == updates[:status].downcase }[0]
        if value.nil?
          return Sifter.detailed_return(project.client.detailed_return,
                  :successful => false,
                  :message => 'You provided an invalid value for \'status\'.')
        end      
        
        update_form.radiobuttons.find {|field| field.value.to_s.downcase == value.to_s.downcase}.check
      end
      
      editable_attributes.delete(:status)
      editable_attributes.each do |attribute|
        if updates.keys.include?(attribute)
          value = value_for("comment[#{attribute.to_s}_id]", update_form, updates[attribute])
          
          if value.nil?
            return Sifter.detailed_return(project.client.detailed_return,
                    :successful => false,
                    :message => "You provided an invalid value for '#{attribute.to_s}'.")
          end

          update_form.field("comment[#{attribute.to_s}_id]").value = value
        end
      end
      
      begin
        project.client.agent.submit(update_form, update_form.buttons.first)
        
        return Sifter.detailed_return(project.client.detailed_return, 
                :successful => true,
                :message => 'The issue was successfully updated.')
      rescue
        return Sifter.detailed_return(project.client.detailed_return, 
                :successful => false,
                :message => 'An unexpected error occured. Please try again.')
      end
      
    end
    
    def value_for(field, form, text)
      form.field(field).options.find {|field| field.text.downcase == text.downcase}
    end
  end
end