module Sifter
  class Client
    attr_accessor :detailed_return
    attr_reader :agent, :subdomain, :username, :projects
  
    # Provide the subdomain, username, and password of the user that you want to login.
    # If the login is successful, then load the user's projects.
    def initialize(subdomain, username, password, load = true)
      @detailed_return = false
    
      @agent = WWW::Mechanize.new
      @agent.user_agent_alias = 'Mac FireFox'
    
      @subdomain, @username, @password = subdomain, username, password
    
      if login(subdomain, username, password) && load
        load_projects
      end
    end
    
    # The full URL to the Sifter application, including the subdomain.
    def site
      "http://#{subdomain}.sifterapp.com"
    end
  
    def login(subdomain, username, password) # :nodoc:
      main_page = @agent.get("http://#{subdomain}.sifterapp.com")
      login_form = main_page.forms.first
    
      if login_form.nil?
        return @logged_in = false
      else
        login_form.username = username
        login_form.password = password
    
        login = @agent.submit(login_form, login_form.buttons.first)
    
        if login.forms.find {|form| form.action == '/session' }
          return @logged_in = false
        else
          return @logged_in = true
        end
      end
    end
    
    # Returns true if the user is logged in, false otherwise.
    def logged_in?
      @logged_in      
    end
    
    # Load the user's projects and put them into the projects instance variable.
    def load_projects
      @projects = parse_projects.collect {|project| Project.new(self, project[:id], project[:name])}
    end
    
    # Reload the user's projects.
    def reload_projects
      @projects.clear
      load_projects
    end
    
    def parse_projects # :nodoc:
      return @agent.get("#{site}/dashboard").at('div.nav/ul').search('li/a').map do |item|
        { 
          :id => item.attributes['href'].match(/projects\/(\d+)\/issues/).to_a.last,
          :name => item.inner_text.strip
        }
      end
    end
  end
end