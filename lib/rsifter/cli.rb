require 'optparse'
require 'base64'

class SifterCLI
  def initialize(command, arguments)
    self.extend(SifterCLICommands)
        
    if arguments.last == '--help'
      send(command.to_sym, arguments)
      exit
    else
      send(command.to_sym, arguments)
      exit
    end
  end
  
  def attempt_login(ask = false)
    if File.exists?(credentials_file) && !ask
      subdomain, username, password = *File.read(credentials_file).split(': ')
      password = Base64.decode64(password)
      
      @client = Sifter::Client.new(subdomain, username, password)
      
      unless @client.logged_in?
        puts 'Stored credentials not authenticated. Enter new credentials:'
        attempt_login(true)
      end
    else
      subdomain = ask_for_subdomain
      username = ask_for_username
      password = ask_for_password
    
      @client = Sifter::Client.new(subdomain, username, password)

      if @client.logged_in?
        create_credentials_for(subdomain, username, password)
      else
        puts 'Authentication failed.'
        exit
      end
    end
    
    @client.detailed_return = true
  end
  
  def credentials_file
    "#{ENV['HOME']}/.sifter/credentials"
  end
  
  def create_credentials_for(subdomain, username, password)
		FileUtils.mkdir_p(File.dirname(credentials_file))
		
  	File.open(credentials_file, 'w') do |f|
  		f.puts "#{subdomain}: #{username}: #{Base64.encode64(password)}"
  	end
  	
  	set_permissions_for(credentials_file)
  end
  
  def ask_for_subdomain
    print 'The subdomain for your app: '
    return gets.strip
  end

  def ask_for_username
    print 'Your username: '
    return gets.strip
  end

  def ask_for_password
    print 'And your password: '
    system "stty -echo"
    password = gets.strip
    system "stty echo"
    puts  
    
    return password
  end
  
  def project_file
    "#{ENV['HOME']}/.sifter/project"
  end
  
  def create_project_file(project)
    FileUtils.mkdir_p(File.dirname(project_file))

  	File.open(project_file, 'w') do |f|
  		f.puts project
  	end

  	set_permissions_for(project_file)
  end
  
  def project
    File.read(project_file).strip rescue nil
  end
  
  def set_permissions_for(file)
		FileUtils.chmod 0700, File.dirname(file)
		FileUtils.chmod 0600, file
  end
  
  def destroy_file(file)
    File.delete(file) rescue ''
  end
end

module SifterCLICommands  
  def projects(arguments)
    if arguments.empty? then projects(['--list']) end
      
    OptionParser.new do |options|
      options.banner = 'usage: sifter project [options]'
      
      options.on('--list', 'The current user\'s projects.') do
        attempt_login
        
        @client.projects.each do |project|
          puts "- \"#{project.name}\""
        end
        
        exit
      end
      
      options.on('--use [name]', String, 'Set the current project.') do |project_name|
        attempt_login

        if @client.projects.collect {|project| project.name}.include?(project_name)
          create_project_file(project_name)
          puts "Project switched to #{project_name}."
        else
          puts "Project #{project_name} does not exist for user #{@client.username}."
        end

        exit
      end
      
      options.on('--current', 'Shows the current project.') do
        if project
          puts 'Current project: ' + project
        else
          puts 'No current project.'
        end
        exit
      end
      
      options.on('--help', 'Show this message.') do
        puts options
        exit
      end
    end.parse!(arguments)
  end
  
  def issues(arguments)
    if arguments.empty?
      issues(['--list'])
    elsif arguments.first != '--help' && arguments.first != '--list'
      issues(['--list', *arguments])
    end
    
    conditions = {}
    parser = OptionParser.new do |options|
      options.banner = 'usage: sifter issues [options]'
      
      options.on('--list', 'Show a list of issues for the current project.') do
        attempt_login
        
        project_name = project
        project_instance = @client.projects.find {|project| project.name == project_name}
        
        if project_instance.nil?
          puts "The project #{project.inspect} no longer exists. Please update the current project using 'sifter project --current'."
          exit
        end
        
        issues = project_instance.issues
        conditions.each do |key, value|
          issues.reject! { |issue| issue.send(key.to_sym).downcase != value.downcase }
        end
        
        issues.each do |issue|
          category = issue.category == '' ? 'No category' : issue.category
          puts "- #{issue.name.inspect}, assigned to #{issue.assigned_to}. #{category}, #{issue.priority.downcase} priority."
        end
      end
      
      conditions_list = {
        'id' => 'i',
        'assigned_to' => 'a',
        'subject' => 't',
        'opened_by' => 'o',
        'status' => 's',
        'priority' => 'p',
        'category' => 'c',
        'comments' => 'n',
        'created' => 'd',
        'updated' => 'u'
      }
      
      conditions_list.each do |attribute, short|
        options.on("-#{short} [#{attribute}]", "--#{attribute} [#{attribute}]", String, "Filter issues based on #{attribute}.") do |value|
          conditions[attribute] = value
        end
      end
      
      options.on('--help', 'Show this message.') do
        puts options
        exit
      end
    end
    
    if arguments.first == '--list'
      arguments.shift
      
      parser.parse!(arguments)
      parser.parse!(['--list'])      
    else
      parser.parse!(arguments)
    end
  end
  
  def user(arguments)
    if arguments.empty? then user(['--show']) end
    
    OptionParser.new do |options|
      options.banner = 'usage: sifter user [options]'
      
      options.on('--login', 'Replace the current user with a new one.') do
        subdomain, username, password = ask_for_subdomain, ask_for_username, ask_for_password
        client = Sifter::Client.new(subdomain, username, password)
        
        if client.logged_in?
          create_credentials_for(subdomain, username, password)
          puts 'Credentials saved.'
          exit
        else
          puts 'Authentication failed, credentials not saved.'
        end
      end
      
      options.on('--flush', 'Flush the old user and prompt for new credentials.') do
        puts 'Flushing old credentials...'
        destroy_file(credentials_file)
        
        puts 'Enter new information: '        
        
        subdomain, username, password = ask_for_subdomain, ask_for_username, ask_for_password
        client = Sifter::Client.new(subdomain, username, password, false)
        
        if client.logged_in?
          create_credentials_for(ask_for_subdomain, ask_for_username, ask_for_password)
          puts 'Credentials saved.'
        else
          puts 'Authentication failed, credentials not saved.'
        end
        
        exit
      end
      
      options.on('--show', 'Show the current stored credentials.') do
        begin
          subdomain, username, password = *File.read(credentials_file).split(': ')
          puts "Current user: #{subdomain} - #{username}"
        rescue 
          puts "No credentials saved."
        end
      end
      
      options.on('--help', 'Show this message.') do
        puts options
        exit
      end
    end.parse(arguments)
  end
end