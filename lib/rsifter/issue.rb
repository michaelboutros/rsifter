module Sifter
  class Issue
    attr_reader :project, :hash, :id, :number, :subject, :opened_by, :assigned_to, :status, :priority, :category, :comments, :date_created, :date_updated
    
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
    end
  end
end