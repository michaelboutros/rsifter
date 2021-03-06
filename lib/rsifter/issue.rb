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
      @comments = []
    end
    
    # Returns the body of the issue. This attribute is not loaded by default because it requires an extra
    # call to the Sifter website.
    def body
      project.client.agent.get(self.url).at('div.description/p').inner_text
    end
    
    # Passed a hash with symbols as the keys, this method will update the issue. The only attributes editable are:
    # priority, category, status, assignee (or assigned_to), subject, and body. When creating a comment, this method
    # is used if the comment updates any of the above mentioned attributes.
    def update(updates)
      updates.reject! {|key, value| value.nil? || value.strip == '' }
      
      if updates.empty?
        return Sifter.detailed_return(project.client.detailed_return,
          :successful => true,
          :message => 'No updates or changes made.')
      end
      
      update_subject_and_body(updates)
      update_others(updates)
    end
    
    # Load this issue's comments unless they have already been loaded. If true is passed, they are loaded regardless.
    def comments(reload = false)
      @comments = load_comments.collect {|comment| Comment.new(self, comment[:id], comment[:author], comment[:body], comment[:changes], comment[:date_created])} if reload || @comments.nil?
      return @comments
    end
    
    def load_comments # :nodoc:
      return project.client.agent.get(url).search('div.comment').map do |issue|
        body ||= begin
          if (paras = issue.at('div.container').search('p')).length == 2
            paras.to_a.last.inner_text.strip
          else
            ''
          end
        end

        {
          :id => issue.attributes['id'].match(/comment_(\d+)/).to_a.last,
          :author => issue.at('span.commenter').inner_text,
          :body => body,
          :changes => (issue.at('div.container/p.changes').inner_text.strip rescue ''),
          :date_created => DateTime.parse(issue.at('span.created').inner_text)
        }
      end
    end
    
    # Reload this issue's comments.
    def reload_comments!
      @comments.clear
      load_comments(true)
    end
    
    def create_comment(comment)
      if comment.nil? || comment.empty?
        return Sifter.detailed_return(project.client.detailed_return,
          :successful => false,
          :message => 'No comment values provided, comment not created.')
      end
      
      if comment.keys.include?(:assigned_to)
        comment[:assignee] = comment[:assigned_to]
        comment.delete(:assigned_to)
      end
      
      fields = [:body, :status, :priority, :category, :assignee]
      
      if !(comment.keys - fields).empty?
        return Sifter.detailed_return(project.client.detailed_return,
          :successful => false,
          :message => "You provided too many fields. The only fields for adding a comment are: #{fields.collect {|field| field.to_s}.join(', ')} (or assigned_to).")
      end
      
      issue_page = self.project.client.agent.get(self.url)
      comment_form = issue_page.forms.first
      
      if !comment[:body].nil?
        comment_form.field('comment[body]').value = comment[:body]
        comment.delete(:body)
      end
      
      if !comment[:status].nil?
        value = get_actual_status(comment[:status])
        
        if value.nil?
          return Sifter.detailed_return(project.client.detailed_return,
                  :successful => false,
                  :message => 'You provided an invalid value for \'status\'.')
        end      
        
         comment_form.radiobuttons.find {|field| field.value.to_s.downcase == value.to_s.downcase}.check
         comment.delete(:status)
      end
      
      comment.keys.each do |field|
        value = value_for("comment[#{field.to_s}_id]", comment_form, comment[field])
        
        if value.nil?
          return Sifter.detailed_return(project.client.detailed_return,
                  :successful => false,
                  :message => "You provided an invalid value for '#{field.to_s}'.")
        end

        comment_form.field("comment[#{field.to_s}_id]").value = value
      end
      
      begin
        project.client.agent.submit(comment_form, comment_form.buttons.first)
        return Sifter.detailed_return(project.client.detailed_return,
          :succussful => true,
          :message => 'Comment successfully created.')
      rescue
        return Sifter.detailed_return(project.client.detailed_return,
          :successful => false,
          :body => 'An unexpected error occured. Please try again.')
      end
    end
    
    def update_subject_and_body(updates) # :nodoc:
      if (subject = updates.keys.include?(:subject)) || (body = updates.keys.include?(:body))
        update_page = project.client.agent.get(self.url + '/edit')
        update_form = update_page.forms.first
        
        if subject
          update_form.field('issue[subject]').value = updates[:subject]
        end
        
        if body
          update_form.field('issue[description]').value = updates[:body]
        end
        
        begin
          project.client.agent.submit(update_form, update_form.buttons.first)
        rescue
          return Sifter.detailed_return(project.client.detailed_return,
                  :successful => false,
                  :message => 'An unexpected error occured when updating the subject and/or body.')
        end
      end
    end
    
    def update_others(updates) # :nodoc:
      editable_attributes = [:priority, :category, :assignee]
      all_editable_attributes = [:status, :subject, :body, *editable_attributes]
      
      if updates.keys.include?(:assigned_to)
        updates[:assignee] = updates[:assigned_to]
        updates.delete(:assigned_to)
      end
      
      if !(updates.keys - all_editable_attributes).empty?
        attributes_list = all_editable_attributes.collect {|attribute| attribute.to_s}.join(', ')
        
        return Sifter.detailed_return(project.client.detailed_return, 
                :successful => false, 
                :message => "You provided invalid updates. Only the following are available for updating: #{attributes_list}.") 
      end
      
      issue_page = self.project.client.agent.get(self.url)
      update_form = issue_page.forms.first
      
      # Change the status value explicitly, since "opened" can mean either opened or reopened.
      if updates.keys.include?(:status)
        value = get_actual_status(updates[:status])
        
        if value.nil?
          return Sifter.detailed_return(project.client.detailed_return,
                  :successful => false,
                  :message => 'You provided an invalid value for \'status\'.')
        end      
        
        update_form.radiobuttons.find {|field| field.value.to_s.downcase == value.to_s.downcase}.check  
      end

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
    
    def get_actual_status(status)
      if status == 'open' && self.status != 'Open'
        status = 'reopened'
      end
      
      if status == 'resolved' && self.status == 'Closed'          
        return Sifter.detailed_return(project.client.detailed_return,
                :successful => false,
                :message => 'You cannot change a closed issue to resolved.')
      end
      
      status_codes = {'1' => 'Open', '2' => 'Reopened', '3' => 'Resolved', '4' => 'Closed'}
      return status_codes.to_a.find {|code, status_text| status_text.downcase == status.downcase }[0]
    end
    
    def value_for(field, form, text) # :nodoc:
      form.field(field).options.find {|field| field.text.downcase == text.downcase}
    end
  end
end