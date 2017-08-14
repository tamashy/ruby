#!/usr/local/rvm/rubies/ruby-2.3.1/bin/ruby
# Ruby script for EDI transfer project
# Author Maxim Ivanov
# Modified by Sergey Bulavintsev

# 20170810 v14 - Added parser for arguments, you can now download files consequently

require 'yaml'
require 'optparse'
require_relative 'edi-parts/ftp_part'
require_relative 'edi-parts/sftp_part_test'
require_relative 'edi-parts/local_part'


# By default we don't want verbose output and want to download files asyncroneously 
options = {:verbose=>false, :single=>false }

# Show help if no arguments passed
ARGV << '-h' if ARGV.empty?

# Parse all passed options and store them in options array
parser = OptionParser.new do|opts|
	opts.banner = "Usage: transfer.rb CONFIG.YML [options]"
	opts.separator ""
	opts.separator "This is a EDI transfer script"
	opts.separator "Specify full path to configuration file in YAML"
	opts.separator "By default we're trying to download file asyncroneously"
	opts.separator ""
	opts.separator "Options"
	opts.on('-v', '--verbose', 'Turn on verbose output') do |verbose|
		options[:verbose] = true;
		
	end
        #Turn it on if scripts can't remove files from SFTP
	opts.on('-s', '--single', 'Download files in single mode one-by-one, synchroneously') do |sync|
		options[:single] = true;
	end

	opts.on('-h', '--help', 'Displays Help') do
		puts opts
		exit
	end
end
parser.parse!
# Check if YAML configuration has been passed, otherwise exit
v1 = ARGV[0]
unless v1
  STDERR.puts("Please specify a valid YAML configuration file")
  Process.exit 1
end

if options[:verbose]
  puts "Using following options: #{options} "
end

#Reading the conf file
CONFIG = YAML.load_file(v1) unless defined? CONFIG

d_protocol = CONFIG['down_stream']['protocol']
u_protocol = CONFIG['up_stream']['protocol']
work_path = CONFIG['defaults']['dir_local']
lock_proc = ProtectionProcess.new
lfile = lock_proc.create_file(work_path) 

log_error("----------START SCRIPT----------")
log_error("Checking if transfer process is running already")
lock_proc.lock_file(lfile)

if d_protocol.downcase.match(/^ftp/)
#  log_error("Open d_connection")
  d_connection = connect_ftp(CONFIG['down_stream']['hostname'], CONFIG['down_stream']['user'], CONFIG['down_stream']['password'])
  download_from_ftp(d_connection, CONFIG['defaults']['dir_local'], CONFIG['down_stream']['backup_dir'], CONFIG['defaults']['regexp'], CONFIG['down_stream']['remote_dir'])
  close_connection(d_connection)
#  log_error("Close d_connection")
elsif d_protocol.downcase.match(/^sftp/)
#  log_error("Open sfd_connection")
  sfd_connection = connect_sftp(CONFIG['down_stream']['hostname'], CONFIG['down_stream']['user'], CONFIG['down_stream']['password'], CONFIG['down_stream']['port'], options[:verbose])
  download_from_sftp(sfd_connection, CONFIG['down_stream']['remote_dir'], CONFIG['defaults']['dir_local'], CONFIG['down_stream']['backup_dir'], CONFIG['defaults']['regexp'], options[:verbose],options[:single])
 #sftp_close_connection(sfd_connection)
#  log_error("Close d_connection")
elsif d_protocol.downcase.match(/local/)
  log_error("Local catalog checking detected. Going to check local store.")
else
  log_error("Unsupported protocol. Please use FTP or sFTP.")
end

if u_protocol.downcase.match(/^ftp/)
#  log_error("Open u_connection")
  u_connection = connect_ftp(CONFIG['up_stream']['hostname'], CONFIG['up_stream']['user'], CONFIG['up_stream']['password'])
  upload_ftp(u_connection, CONFIG['defaults']['dir_local'], CONFIG['up_stream']['dst_dir'], CONFIG['defaults']['regexp'])
  close_connection(u_connection)
elsif u_protocol.downcase.match(/^sftp/)
  sfu_connection = connect_sftp(CONFIG['up_stream']['hostname'], CONFIG['up_stream']['user'], CONFIG['up_stream']['password'], CONFIG['up_stream']['port'], options[:verbose])
  upload_to_sftp(sfu_connection, CONFIG['defaults']['dir_local'], CONFIG['up_stream']['dst_dir'], CONFIG['defaults']['regexp'])
  #sftp_close_connection(sfu_connection)
else
  log_error("Unsupported protocol. Please use FTP or sFTP.")
  #exit 7
end

local_clean_up(CONFIG['defaults']['dir_local'], CONFIG['defaults']['backup_local'], CONFIG['defaults']['regexp'])

log_error("Removing a lock file.")
File.delete(lfile)

log_error("----------END SCRIPT----------")

