require 'yaml'
require_relative 'edi-parts/ftp_part'
require_relative 'edi-parts/sftp_part'
require_relative 'edi-parts/local_part'

BANNER = "The configuration file must be specified!"

v1 = ARGV[0]
unless v1
  STDERR.puts(BANNER)
  Process.exit 1
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
  d_connection = connect_ftp(CONFIG['down_stream']['hostname'], CONFIG['down_stream']['user'], CONFIG['down_stream']['password'])
  download_from_ftp(d_connection, CONFIG['defaults']['dir_local'], CONFIG['down_stream']['backup_dir'], CONFIG['defaults']['regexp'], CONFIG['down_stream']['remote_dir'])
  close_connection(d_connection)
elsif d_protocol.downcase.match(/^sftp/)
  sfd_connection = connect_sftp(CONFIG['down_stream']['hostname'], CONFIG['down_stream']['user'], CONFIG['down_stream']['password'], CONFIG['down_stream']['port'])
  download_from_sftp(sfd_connection, CONFIG['down_stream']['remote_dir'], CONFIG['defaults']['dir_local'], CONFIG['down_stream']['backup_dir'], CONFIG['defaults']['regexp'])
 #sftp_close_connection(sfd_connection)
elsif d_protocol.downcase.match(/local/)
  log_error("Local catalog checking detected. Going to check local store.")
else
  log_error("Unsupported protocol. Please use FTP or sFTP.")
end

if u_protocol.downcase.match(/^ftp/)
  u_connection = connect_ftp(CONFIG['up_stream']['hostname'], CONFIG['up_stream']['user'], CONFIG['up_stream']['password'])
  upload_ftp(u_connection, CONFIG['defaults']['dir_local'], CONFIG['up_stream']['dst_dir'], CONFIG['defaults']['regexp'])
  close_connection(u_connection)
elsif u_protocol.downcase.match(/^sftp/)
  sfu_connection = connect_sftp(CONFIG['up_stream']['hostname'], CONFIG['up_stream']['user'], CONFIG['up_stream']['password'], CONFIG['up_stream']['port'])
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

