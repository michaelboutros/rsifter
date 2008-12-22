module Sifter
  class Issue
    attr_reader :id, :title, :opened_by, :assigned_to, :status, :priority, :category, :comments, :date_created, :date_updated
    
    def initialize(project, details) # :nodoc:
      @project = project
      details.each {|key, value| instance_variable_set(:"@#{key}", value)}
      
      if @category == ''
        @category = 'None'
      end
    end
  end
end