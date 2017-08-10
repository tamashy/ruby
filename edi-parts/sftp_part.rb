require 'net/sftp'
require 'net/ssh'

#Method for connecting to the server by sFTP protocol
def connect_sftp(hostname, username, password, port=22)
  begin
    log_error("Connecting to remote server #{hostname} by sFTP protocol")
    sftp = Net::SFTP.start(hostname, username, :password => password, :port => port, :timeout => 20, :keepalive => true, :keepalive_maxcount => 3, :keepalive_interval => 10) #, :number_of_password_prompts => "#{prompts}") #:verbose=>:debug,
  rescue Net::SSH::ConnectionTimeout => timeout_error
    log_error("Timed out: #{timeout_error}")
  rescue Net::SSH::AuthenticationFailed => login_error
    log_error("Authentication failure")
  rescue Errno::EHOSTUNREACH => login_error
    log_error("Host unreachable")
  rescue Errno::ECONNREFUSED => login_error
    log_error("Connection refused")
  ensure
  log_error("Ensuring sftp state")
  if sftp.nil?
    log_error("Unable to connect to the sFTP server: #{hostname}")
    exit 2
  elsif sftp.open?
    log_error("Connected to the sFTP server #{hostname}")
  else
    log_error("Ftp connection established, but not open")
    exit 2
  end
  end
end

class CustomHandler
  def on_open(uploader, file)
    log_error "starting upload: #{file.local} -> #{file.remote} (#{file.size} bytes)"
  end

  def on_put(uploader, file, offset, data)
    log_error "writing #{data.length} bytes to #{file.remote} starting at #{offset}"
  end

  def on_close(uploader, file)
    log_error "finished with #{file.remote}"
  end

  def on_mkdir(uploader, path)
    log_error "creating directory #{path}"
  end

  def on_finish(uploader)
    log_error "all done!"
  end
end


#Method for downloading the files from sFTP server only if files conform to the regexp.
def download_from_sftp(sfd_connection, remote_dir, dir_local, backup_rem_dir, file_regex)
  s_file = []
  sfd_connection.dir.entries(remote_dir).map do |entry|
    s_file << entry.name
  end
  s_file -= [".",".."]
  s_file = s_file.select{|f| f =~ /#{file_regex}/}
  if s_file.empty? == true
    log_error("There are no files to be downloaded from sFTP server")
  else
    log_error("These files are going to be downloaded: #{s_file} from sFTP server")

    full_rem_dir = sfd_connection.realpath!(remote_dir).name
    full_rem_back_dir = sfd_connection.realpath!(backup_rem_dir).name

    dls = s_file.map{|item| sfd_connection.download(full_rem_dir + "/" + item, dir_local + "/" + item)}
    dls.each{|d| d.wait}
    log_error("All files have been downloaded from sFTP server.")
    if full_rem_back_dir.empty?
      log_error("Please pay attention: There is no remote backup folder.")
    else
      log_error("Moving files to the remote backup dirrectory #{full_rem_back_dir}.")
      uls = s_file.map{|item| sfd_connection.upload!(dir_local + "/" + item, full_rem_back_dir + "/" + item, :progress => CustomHandler.new)}
      uls.each{|u| u.wait}
    end

    s_file.map{|item| sfd_connection.remove!(full_rem_dir + "/" + item)}
  end
  rescue Net::SFTP::StatusException => access_error
    log_error("Permission denied. A badly formatted packet or other SFTP protocol incompatibility was detected: #{access_error.message}")
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
      data_files = local_file.select {|x| x !~ /END|end/}
      log_error("These files are going to be uploaded: #{data_files} to the sFTP server")
      data_uls = data_files.map{|item| sfu_connection.upload!(dir_local + item, full_rem_dir  + "/" + item, :progress => CustomHandler.new)}
      data_uls.each{|u| u.wait}
      end_files = local_file.select {|x| x =~ /END|end/}
      log_error("These files are going to be uploaded: #{end_files} to the sFTP server")
      end_uls = end_files.map{|item| sfu_connection.upload!(dir_local + item, full_rem_dir  + "/" + item, :progress => CustomHandler.new)}
      end_uls.each{|u| u.wait}
    end
  rescue Net::SFTP::StatusException => access_error
    log_error("Permission denied, because of #{access_error.message}")
end

#Method for sFTP connection closure
def sftp_close_connection(connection)
   connection.close!(connection)
end

