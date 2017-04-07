require 'fileutils'

#Method for recording actions to the log file
def log_error(error)
  log_file = CONFIG['defaults']['log_file']
  if File.exist?(log_file)
    File.open(log_file, 'a') do |log|
    log.puts Time.now.strftime("%Y-%m-%d %H:%M:%S") + ": " + error
    end
  else
    File.new(log_file, 'w+')
  end
end

#Class for managing lock file
class ProtectionProcess
  def create_file(path)
    File.new(path + 'lock_file', 'w+')
  end

  def lock_file(file)
    if file.flock(File::LOCK_EX | File::LOCK_NB) == false
      log_error("*** can't lock file, another instance of script is running?  exiting")
      exit 2
    else
      file.flock(File::LOCK_EX)
    end
  end

  def write_to_file(file, message)
    f = File.open(file, 'w+')
    f.write message
  end
end

#Housekeeping in the local dirrectory
def local_clean_up(dir_local, backup_local, regexp)
  Dir.foreach(dir_local) do |file|
    if file =~ /#{regexp}/ && File.file?(file)
      FileUtils.mv(file, backup_local)
      log_error("File #{file} moved to the local backup path: #{backup_local} ")
    end
  end
  log_error("There are no files to be stored in the local backup directory: #{backup_local}")
  rescue Errno::ENOTDIR => path_error
    log_error("No such dirrectory! #{backup_local} #{path_error}")
end

