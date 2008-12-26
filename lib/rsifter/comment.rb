module Sifter
  class Comment
    attr_reader :issue, :id, :author, :body, :changes, :date_created
    
    def initialize(issue, id, author, body, changes, date_created)
      @issue, @id, @author, @body, @changes, @date_created = issue, id, author, body, changes, date_created
    end
    
    alias :original_inspect :inspect
    def inspect 
      "#<Sifter::Comment @issue=<Sifter::Issue @id=#{issue.id.inspect}>, @id=#{id.inspect}, @author=#{author.inspect}, @body=#{body.inspect}, @changes=#{changes.inspect}, @date_created=#{date_created.inspect}>"
    end
    alias :to_s :inspect
  end
end