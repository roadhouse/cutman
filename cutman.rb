#!/usr/bin/env ruby

# == Synopsis
#   The simple command line passenger apps manager
#
#
# == Examples
#   This command list the apps already configured:
#     cutman -l
#
#   Other examples:
#     cutman -a projects/my_15min_blog
#     cutman -d my_15min_blog.local
#
# == Usage
#   cutman [options] app_dir
#
#   For help use: cutman -h
#
# == Options
#   -l, --list                  List all apps configured
#   -a, --add app_name app_path Add a new app to apache config
#   -d, --delete                Delete an app from apache config
#   -h, --help                  Displays help message         
#   -v, --version               Display the version, then exit
#
# == Author
#   Jean Uchôa (RoadHouse)
#
# == Copyright
#   Copyright (c) 2010 Jean Uchôa. Licensed under the MIT License:
#   http://www.opensource.org/licenses/mit-license.php
#
# TO DO - support to linux (ubuntu)

require 'optparse'
require 'ostruct'
require 'rdoc/usage'

class CutMan
  VERSION = '0.0.1alpha'
  CUTMAN_DIR = "/etc/apache2/cutman_vhosts/"

  attr_reader :options

  def initialize(arguments, stdin)
    @arguments        = arguments
    @stdin            = stdin

    @options          = OpenStruct.new
    @options.list     = false
    @options.add      = false
    @options.delete   = false
    @options.app_path = nil
    @options.app_name = nil
  end

  def run
    if parsed_options?
      do_action
    else
      output_usage
    end
  end

  protected
  
    def output_usage
       RDoc::usage('usage')
     end
  
    def do_action
      if @options.list
        list_apps
      elsif @options.add
        add_app
      elsif @options.delete
        delete_app
      end
    end
    
    def list_apps
      system('dscl localhost -list /Local/Default/Hosts')
    end
    
    def apache_vhost_config
      config = <<-EOC
      <VirtualHost *:80>
        ServerName #{@options.app_name}
        DocumentRoot "#{@options.app_path}/public"
        RailsEnv development
        <directory "#{@options.app_path}/public">
          Order allow,deny
          Allow from all
        </directory>
      </VirtualHost>
      EOC
    end
    
    def write_vhost_config
      file = File.new("#{CUTMAN_DIR}#{@options.app_name}.vhost.conf", "w")
      file.puts(apache_vhost_config)
    end
    
    def create_local_domain
      system("dscl localhost -create /Local/Default/Hosts/#{@options.name} IPAddress 127.0.0.1")
    end
    
    def restart_apache
      system("apachectl restart")
    end
    
    def initial_apache_setup
      apache_initial_config = <<-EOC
      <IfModule passenger_module>
        NameVirtualHost *:80
        Include #{CUTMAN_DIR}*.conf
      </IfModule>
      EOC
      
      current_date = Time.now
      
      system("cp /etc/apache2/httpd.conf /etc/apache2/httpd.conf.bkp.#{Time.now.strftime("%Y%m%d%H%M")}")
      system("echo #{apache_initial_config} >> /etc/apache2/httpd.conf")
      system("mkdir #{CUTMAN_DIR}")
    end
      
    def add_app
      inital_apache_setup unless File.exist?(CUTMAN_DIR)
      write_vhost_config
      create_local_domain
      restart_apache
      p "The #{@options.app_name} -> #{@options.app_path} was created"
    end
    
    def delete_vhost_config
      vhost_path = "#{CUTMAN_DIR}#{@options.app_name}.vhost.conf"
      File.delete(vhost_path) if File.exist?(vhost_path)
      p "The #{@options.app_name} was deleted"
    end
    
    def delete_app
      delete_vhost_config
      restart_apache
    end

    def input_options
      opts = OptionParser.new do |opts|
        opts.on("-h", "--help") { RDoc::usage('options') }
        opts.on("-v", "--version") { p "#{VERSION}" }
        opts.on("-l", "--list") { @options.list = true }
        opts.on("-a", "--add")  { @options.add = true }
        opts.on("-d", "--delete APP_NAME") { |app_name| @options.delete = true; @options.app_name = app_name }
      end
    end

    def parsed_options?
      begin
        input_options.parse!(@arguments)
        process_options
      rescue
        return false
      end
      return true
    end

    def process_options
      if @options.list
        @options.add = false
        @options.delete = false
      elsif @options.add
        raise OptionParser::MissingArgument if @arguments.length != 2
        @options.list = false
        @options.delete = false
        @options.app_name = @arguments[0]
        @options.app_path = @arguments[1]
      elsif @options.delete
        @options.add = false
        @options.list = false
      end
    end

end

#The main execution
begin
  robot = CutMan.new(ARGV, STDIN)
  robot.run 
rescue Errno::EACCES => e
  p "This command require sudo"
end