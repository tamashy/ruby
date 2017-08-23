require 'net/ftp'

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

#Method for downloading the files from FTP server only if files conform to the regexp.
def download_from_ftp(d_connection, dir_local, backup_rem_dir, file_regex, remote_dir)
  d_connection.chdir(remote_dir)
  files = d_connection.nlst.select{|e| e =~ /#{file_regex}/}
  log_error("#{files} has been generated")
  if files.empty? == true
    log_error("There are no files to be downloaded from FTP server")
  else
    files.each do |f|
      log_error("This file is going to be downloaded: #{f} #{d_connection.last_response_code}")
      downloaded_file = dir_local + f
      log_error("#{downloaded_file} has been generated")
      backup_file = backup_rem_dir + f
      log_error("#{downloaded_file} #{f} get")
      d_connection.get(f, downloaded_file)
      log_error("#{downloaded_file} #{f} get")
      log_error("File #{f} has been downloaded")
      d_connection.put(downloaded_file, backup_file)
      log_error("The file #{f} has been moved to the backup folder: #{backup_rem_dir} #{d_connection.last_response_code}")
      d_connection.delete(f)
    end
  end
  rescue Net::FTPPermError => access_error
    log_error("Unable to put the file:  #{d_connection.last_response_code}")
end

#Method uploading the files which are conform the regexp to the server by FTP protocol.
def upload_ftp(u_connection, dir_local, upload_dir, file_regex)
  Dir.chdir(dir_local)
  Dir.foreach(dir_local) do |file|
   if file =~ /#{file_regex}/
     log_error("This file is going to be uploaded:  #{file}")
     u_connection.chdir(upload_dir)
       if file =~ /\.csv$/
         u_connection.putbinaryfile(file, file)
       else
         u_connection.puttextfile(file, file)
       end
     log_error("The file has been uploaded: #{file} #{u_connection.last_response_code}")
   end
  end
  log_error("No more files to be uploaded to the FTP server")
end

#Method for FTP connection closure
def close_connection(connection)
  connection.close
end

