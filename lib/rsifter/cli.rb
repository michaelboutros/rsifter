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
  
  def attempt_login(ask = false, load = false)
    if File.exists?(credentials_file) && !ask
      puts 'Logging in...'
      subdomain, username, password = *File.read(credentials_file).split(': ')
      password = Base64.decode64(password)
      
      @client = Sifter::Client.new(subdomain, username, password, load)
      
      unless @client.logged_in?
        puts 'Stored credentials not authenticated. Enter new credentials:'
        attempt_login(true, false)
      end
    else
      puts 'Logging in...'
      
      subdomain = ask_for_subdomain
      username = ask_for_username
      password = ask_for_password
    
      @client = Sifter::Client.new(subdomain, username, password, load)

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
  
  def format_file
    "#{ENV['HOME']}/.sifter/format"
  end
  
  def create_format_file(format)
    FileUtils.mkdir_p(File.dirname(format_file))

   	File.open(format_file, 'w') do |f|
   		f.puts format
   	end

    set_permissions_for(format_file)   
  end
  
  def format
    File.read(format_file) rescue "- {name.inspect}, assigned to {assigned_to}. {category}, {priority.downcase} priority."
  end
  
  def formatted(issue)    
    format.gsub(/\{(.+?)\}/) do |match|
      manipulations = match.delete('{}').split('.')
      attribute = manipulations.shift
      
      value = issue.send(attribute.to_sym)      
      manipulations.each do |manipulation|
        value = value.send(manipulation.to_sym)
      end
      
      value
    end
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
      
      options.on('--use [name]', String, 'Set the current project.') do |project_name_or_id|   
        attempt_login      
        project_name = @client.project(project_name_or_id).name
      
        if @client.project(project_name).name == project
          puts "This project is already the current project. No changes made."
          exit
        elsif !@client.project(project_name).nil?
          create_project_file(project_name)
          puts "Project switched to #{@client.project(project_name).name}."
        else
          puts "Project #{project_name} does not exist for user #{@client.username}."
        end
      end
      
      options.on('--current', 'Shows the current project.') do
        if project
          puts 'Current project: ' + project.inspect
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
    elsif !['--help', '--format', '--list', '--update'].include?(arguments.first)
      issues(['--list', *arguments])
    end
    
    issue_hash, sort_option = {}, nil
    parser = OptionParser.new do |options|
      options.banner = 'usage: sifter issues [options]'
      
      options.on('--project [project]', String, 'Show this project\'s issues instead of the current project\'s issues.') do |project|
        entered_project = project
      end
      
      options.on('--format [format]', String, 'The format used to list issues. See docs for more information.') do |entered_format|
        if entered_format.nil?
          puts format
        elsif entered_format == format
          puts 'Entered format is the save as current format. No changes made.'
        else
          create_format_file(entered_format.gsub(/\\-/, '-'))
          puts "Format #{entered_format.gsub(/\\-/, '-').inspect} saved."
        end
      end
      
      options.on('--sort [sort]', 'Sort list of issues by [sort], ie. name DESC. Default direction is ASC') do |sort|
        sort_option = sort
      end
      
      conditions_list = {
        'id' => 'i',
        'assigned_to' => 'a',
        'subject' => 't',
        'opened_by' => 'o',
        'status' => 's',
        'priority' => 'p',
        'category' => 'c',
        'created' => 'd',
        'updated' => 'u',
        'body' => 'b'
      }
      
      conditions_list.each do |attribute, short|
        options.on("-#{short} [#{attribute}]", "--#{attribute} [#{attribute}]", String, "Filter issues based on #{attribute}.") do |value|
          issue_hash[attribute] = value
        end
      end
      
      options.on('--list', 'Show a list of issues for the current project.') do
        attempt_login
        
        project_name = entered_project rescue project
        project_instance = @client.project(project_name)
        
        if project_instance.nil?
          puts "The project #{project_name.inspect} does not exist. Please update the current project using 'sifter project --current', or enter a different project."
          exit
        end
        
        issues = project_instance.issues
        
        unless sort_option.nil? 
          attribute, direction = *sort_option.split(' ')
          
          if issues.first.hash.keys.include?(attribute.to_sym)
            issues = issues.sort_by {|issue| issue.send(attribute.to_sym)}
            
            if direction && direction == 'desc'
              issues.reverse!
            end
          end
        end
        
        issue_hash.each do |key, value|
          issues.reject! { |issue| issue.send(key.to_sym).downcase != value.downcase }
        end
        
        issues.each do |issue|
          puts formatted(issue)
        end
      end
      
      options.on('--update [selector]', 'Update the issue with the flags passed. See --help for available flags.') do |issue_selector|
        if issue_selector.nil?
          puts 'You must pass an issue id, number, or name to find the issue you want to update.'
          exit
        end
        
        attempt_login
        
        issue = @client.project(project).issue(issue_selector)
        if issue.is_a?(Hash) && issue[:successful] == nil
          puts 'Issue not found.'
          exit
        end
        
        update_hash = issue_hash.each {|key, value| issue_hash.delete(key) and issue_hash[key.to_sym] = value}
        update = issue.update(update_hash)
        
        puts update[:message]       
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
    elsif arguments.first == '--update'
      arguments.shift
      selector = arguments.shift
      
      parser.parse!(arguments)
      parser.parse!(['--update', selector])
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