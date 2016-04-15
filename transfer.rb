require 'net/ftp'
require 'find'
require 'fileutils'
require 'yaml'
require 'net/sftp'
require 'rubygems'
require 'net/ssh'

BANNER = "The configuration file must be specified!"

=begin
v1 = if ARGV[0]
  ARGV[0]
else
  puts "The configuration file must be specified"
  exit 1
end
=end

v1 = ARGV[0]
unless v1
  STDERR.puts(BANNER)
  Process.exit 1
end

#Reading the conf file
CONFIG = YAML.load_file(v1) unless defined? CONFIG

d_protocol = CONFIG['down_stream']['protocol']
u_protocol = CONFIG['up_stream']['protocol']
#work_path = CONFIG['defaults']['dir_local']

#Method for recording actions to the log file
def log_error(error)
  log_file = CONFIG['defaults']['log_file']
  if File.exist?(log_file)
    File.open(log_file, 'a') do |log|
    log.puts Time.now.to_s + ": " + error
    end
  else
    File.new(log_file, 'w+')
  end
end

#Method for creating lock file
#def lock_file()
#  File.new(work_path + '/' + 'lock_file', 'w+')  
#end


#Method for FTP connection esteblishing
def connect_ftp(hostname, username, password)
 # Login to the FTP server
    ftp = Net::FTP.new(hostname, username, password)
  rescue Errno::EHOSTUNREACH => login_error
    log_error("No route to host '#{hostname}'")
  rescue Net::FTPPermError => login_error
    log_error("FTP Server not allowing logins for '#{username}' using '#{password}': #{login_error}")
  rescue SocketError => socket_error
    log_error("Error Connecting To FTP: #{socket_error}")
  rescue TimeoutError => timeout_error
    log_error("FTP connection timed out: #{timeout_error}")
  ensure  
  if ftp.last_response_code.match(/220|200/)
    log_error("Connected to the FTP server: #{hostname}")
  else
    log_error("FTP Server down or not responding #{ftp.last_response_code}")
  end
end

#Method for connecting to the server by sFTP protocol
def connect_sftp(hostname, username, password)
    log_error("Connecting to remote server #{hostname} by sFTP protocol")
    sftp = Net::SFTP.start(hostname, username, :password => password, :timeout => 20) #, :number_of_password_prompts => "#{prompts}") #:verbose=>:debug,
  rescue Net::SSH::ConnectionTimeout => timeout_error
    log_error("Timed out: #{timeout_error}")
  rescue Net::SSH::AuthenticationFailed => login_error
    log_error("Authentication failure")
  rescue Errno::EHOSTUNREACH => login_error
    log_error("Host unreachable")
  rescue Errno::ECONNREFUSED => login_error
    log_error("Connection refused")
  ensure
  if sftp.open? == true
    log_error("Connected to the sFTP server #{hostname}")
  else
    log_error("Unable to connect to the sFTP server: #{hostname}")
  end
end

#Method for downloading the files from FTP server only if files conform to the regexp.
def download_from_ftp(d_connection, dir_local, backup_rem_dir, file_regex)
  files = d_connection.nlst.select{|e| e =~ /#{file_regex}/}
  if files.empty? == true
    log_error("There are no files to be downloaded from FTP server")
  else
    files.each do |f|
      log_error("This file is going to be downloaded: #{f} #{d_connection.last_response_code}")
      downloaded_file = dir_local + f
      backup_file = backup_rem_dir + f
      d_connection.get(f, downloaded_file)
      log_error("File #{f} has been downloaded")
      d_connection.put(downloaded_file, backup_file)
      log_error("The file #{f} has been moved to the backup folder: #{backup_rem_dir} #{d_connection.last_response_code}")
      d_connection.delete(f)
    end
  end
  rescue Net::FTPPermError => access_error
    log_error("Unable to put the file: #{f} #{d_connection.last_response_code}")
end

#Method for downloading the files from sFTP server only if files conform to the regexp.
def download_from_sftp(sfd_connection, remote_dir, dir_local, backup_rem_dir, file_regex)
  file = sfd_connection.dir.entries(remote_dir).map {|e| e.name}
  s_file = file.select{|f| f =~ /#{file_regex}/}
  if s_file.empty? == true
    log_error("There are no files to be downloaded from sFTP server")
  else
    log_error("These files are going to be downloaded: #{s_file} from sFTP server")
  
    full_rem_dir = sfd_connection.realpath!(remote_dir).name
    full_rem_back_dir = sfd_connection.realpath!(backup_rem_dir).name
  
    dls = s_file.map{|item| sfd_connection.download(full_rem_dir + "/" + item, dir_local + item)}
    dls.each{|d| d.wait}
    log_error("All files have been downloaded from sFTP server.")
  
    log_error("Moving files to the remote backup dirrectory #{full_rem_back_dir}.")
    uls =  s_file.map{|item| sfd_connection.upload(dir_local + item, full_rem_back_dir + "/" + item) }
    uls.each{|u| u.wait}
  
    s_file.map{|item| sfd_connection.remove!(full_rem_dir + "/" + item)}
  end
  rescue Net::SFTP::StatusException => access_error
    log_error("Permission denied. A badly formatted packet or other SFTP protocol incompatibility was detected: #{access_error.message}")
end

#Method uploading the files which are conform the regexp to the server by FTP protocol.
def upload_ftp(u_connection, dir_local, upload_dir, file_regex)
  Dir.chdir(dir_local)
  Dir.foreach(dir_local) do |file|
   if file =~ /#{file_regex}/
     log_error("This file is going to be uploaded:  #{file}")
     u_connection.chdir(upload_dir)
     u_connection.put(file, file)
     log_error("The file has been uploaded: #{file} #{u_connection.last_response_code}")
   end
  end
  log_error("No more files to be uploaded to the FTP server")
end

#Method uploading the files which are conform the regexp to the server by sFTP protocol.
def upload_to_sftp(sfu_connection, dir_local, upload_dir, file_regex)
  full_rem_dir = sfu_connection.realpath!(upload_dir).name
  Dir.chdir(dir_local)
  local_files = Dir.foreach(dir_local).map{|file| file}
  local_file = local_files.find_all{|x| x =~ /#{file_regex}/}
    if local_file.empty? == true
      log_error("There are no files to be uploaded to the sFTP server")
    else
      log_error("These files are going to be uploaded: #{local_file} to the sFTP server")
      uls = local_file.map{|item| sfu_connection.upload(dir_local + item, full_rem_dir  + "/" + item)}
      uls.each{|u| u.wait}
    end
  rescue Net::SFTP::StatusException => access_error
    log_error("Permission denied, because of #{access_error.message}") 
end

#Housekeeping in the local dirrectory
def local_clean_up(dir_local, backup_local, regexp)
  Dir.foreach(dir_local) do |file|
    if file =~ /#{regexp}/ && File.file?(file)
      FileUtils.mv(file, backup_local)
      log_error("File #{file} moved to the local backup path: #{backup_local} ")
      #log_error("Local files copy have been stored in the local backup directory")
    end
  end
  log_error("There are no files to be stored in the local backup directory: #{backup_local}")
  rescue Errno::ENOTDIR => path_error
  log_error("No such dirrectory! #{backup_local} #{path_error}")
end

#Method for FTP connection closure
def close_connection(connection)
  connection.close
end

=begin
#Method for sFTP connection closure
def sftp_close_connection(connection)
   connection.close!(connection)
end
=end

log_error("----------START SCRIPT----------")
=begin
log_error("Checking if transfer proccess is running already")

if File.exist?(work_path + '/' + 'lock_file')
  log_error("Sorry lock file already exists. Probably another file transfer is running already.")
  exit!
else
  log_error("Creating a lock file.")
  File.new(work_path + '/' + 'lock_file', 'w+')
end
=end

if d_protocol.downcase.match(/^ftp/)
  d_connection = connect_ftp(CONFIG['down_stream']['hostname'], CONFIG['down_stream']['user'], CONFIG['down_stream']['password'])
  download_from_ftp(d_connection, CONFIG['defaults']['dir_local'], CONFIG['down_stream']['backup_dir'], CONFIG['defaults']['regexp'])
  close_connection(d_connection)
elsif d_protocol.downcase.match(/^sftp/)
  sfd_connection = connect_sftp(CONFIG['down_stream']['hostname'], CONFIG['down_stream']['user'], CONFIG['down_stream']['password'])
  download_from_sftp(sfd_connection, CONFIG['down_stream']['remote_dir'], CONFIG['defaults']['dir_local'], CONFIG['down_stream']['backup_dir'], CONFIG['defaults']['regexp'])
 #sftp_close_connection(sfd_connection)
else
  log_error("Unsupported protocol. Please use FTP or sFTP.")
  #exit 6
end


if u_protocol.downcase.match(/^ftp/)
  u_connection = connect_ftp(CONFIG['up_stream']['hostname'], CONFIG['up_stream']['user'], CONFIG['up_stream']['password'])
  upload_ftp(u_connection, CONFIG['defaults']['dir_local'], CONFIG['up_stream']['dst_dir'], CONFIG['defaults']['regexp'])
  close_connection(u_connection)
elsif u_protocol.downcase.match(/^sftp/)
  sfu_connection = connect_sftp(CONFIG['up_stream']['hostname'], CONFIG['up_stream']['user'], CONFIG['up_stream']['password'])
  upload_to_sftp(sfu_connection, CONFIG['defaults']['dir_local'], CONFIG['up_stream']['dst_dir'], CONFIG['defaults']['regexp'])
  #sftp_close_connection(sfu_connection)
else
  log_error("Unsupported protocol. Please use FTP or sFTP.")
  #exit 7
end

local_clean_up(CONFIG['defaults']['dir_local'], CONFIG['defaults']['backup_local'], CONFIG['defaults']['regexp'])
log_error("----------END SCRIPT----------")

=begin
at_exit do
  File.delete(work_path + '/' + 'lock_file')
  log_error("Removing a lock file.")
  log_error("----------END SCRIPT----------")
end
=end
