module Sifter
  class Project
    attr_reader :client, :name, :id, :url
    
    def initialize(client, id, name) # :nodoc:
      url = "#{client.site}/projects/#{id}/issues"
      
      @client, @id, @name, @url = client, id, name, url
    end
    
    # Load one of the project's issues based on criteria. The criteria can be a hash of attributes and their values,
    # the id of the issue, the number of the issue, or the subject of the issue.
    def issue(criteria_or_other)
      reload_issues!
      
      if criteria_or_other.is_a?(Hash)
        begin
          issue = issues.find do |issue|
            matched = false
        
            criteria_or_other.each do |key, value|
              matched = (issue.send(key.to_sym).to_s.downcase == value.to_s.downcase)
            end
        
            matched
          end      
        rescue NoMethodError
          return Sifter.detailed_return(client.detailed_return,
                  :successful => nil,
                  :message => 'Criteria contained invalid attributes.')
        end
      elsif criteria_or_other.is_a?(Integer) || criteria_or_other.to_i != 0
        issue = issues.find {|issue| issue.id.to_s == criteria_or_other.to_s}
      elsif criteria_or_other.is_a?(String)
        issue ||= begin 
          if (number = criteria_or_other.match(/^#(\d+)$/))
            issues.find {|issue| issue.number.to_s == number.to_a.last}
          else
            issues.find {|issue| issue.subject == criteria_or_other}
          end
        end
      end
      
      if issue.nil?
         return Sifter.detailed_return(client.detailed_return,
                  :successful => nil,
                  :message => 'Issue not found.')
      else
        return issue
      end
    end
    
    # Load this project's issues and put them into the issues instance variable, unless they have already been
    # loaded. Pass true as the first argument to reload the issues.
    def issues(reload = false)
      @issues = load_issues.collect {|issue| Issue.new(self, issue)} if reload || @issues.nil?
      return @issues
    end
    
    # Reload this project's issues.
    def reload_issues!
      issues(true)
    end
    
    def load_issues # :nodoc:
      return self.client.agent.get(self.url).search('div.issue').map do |issue|              
        {
          :id => issue.attributes['id'].match(/(\d+)/).to_a.last.strip.to_i,
          :number => issue.search('div.details/h3/span').to_a.first.inner_text.match(/(\d+)/).to_a.last.to_i,
          :subject => issue.at('h3/a').inner_text.strip,
          :opened_by => issue.at('ul.people').search('li/strong').first.inner_text.strip,
          :assigned_to => issue.at('ul.people').search('li/strong').last.inner_text.strip,
          :status => issue.at('li.status').inner_text.strip,
          :priority => issue.at('li.priority').inner_text.strip,
          :category => issue.at('h3').search('span/a').inner_text.strip,
          :comments => (issue.at('span.meta/a').inner_text.match(/(\d+)/).to_a.last.strip rescue '0').to_i,
          :date_created => issue.at('span.meta').inner_text.match(/^(.+?) old/).to_a.last.strip,
          :date_updated => (issue.at('span.meta').inner_text.match(/Last by (.+?) (\d+ .+?) ago$/).to_a.last.strip rescue 'Never')
        }
      end
    end
    
    alias :original_inspect :inspect
    def inspect # :nodoc:
      "#<Sifter::Project @client=Sifter::Client @id=#{@id.inspect}, @name=#{@name.inspect}, @url=#{@url.inspect}>"
    end
    alias :to_s :inspect
  end
end