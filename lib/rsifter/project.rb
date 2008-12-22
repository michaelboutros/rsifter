module Sifter
  class Project
    attr_reader :client, :name, :id, :url
    
    def initialize(client, id, name) # :nodoc:
      url = "#{client.site}/projects/#{id}/issues"
      
      @client, @id, @name, @url = client, id, name, url
    end
    
    # Load this project's issues and put them into the issues instance variable.
    def issues(reload = false)
      @issues = load_issues.collect {|issue| Issue.new(self, issue)} if @issues.nil? || reload
    end    
    
    # Reload this project's issues.
    def reload_issues
      issues(true)
    end
    
    def load_issues # :nodoc:
      return self.client.agent.get(self.url).search('div.issue').map do |issue|               
        {
          :id => issue.attributes['id'].match(/(\d+)/).to_a.last.strip,
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
    def inspect
      "#<Sifter::Project @client=Sifter::Client @id=#{@id.inspect}, @name=#{@name.inspect}, @url=#{@url.inspect}>"
    end
    alias :to_s :inspect
  end
end