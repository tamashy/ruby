###################################################################################################
def  working_folder_create(dst_path, first_side, second_side)
  f_name = {:dir_local => [], :backup_dir => []}

  f_name[:dir_local] << "#{dst_path}/from#{first_side}2#{second_side}/" << "#{dst_path}/from#{second_side}2#{first_side}/"
  f_name[:backup_dir] << "#{dst_path}/from#{second_side}2#{first_side}/backup/" << "#{dst_path}/from#{first_side}2#{second_side}/backup/"
  puts "Going to create working folders"

  f_name[:dir_local].each {|f| FileUtils::mkdir_p "#{f}" unless Dir.exist?("#{f}") }
  puts "Working folders have been created."
  f_name[:backup_dir].each {|f| FileUtils::mkdir_p "#{f}" unless Dir.exist?("#{f}") }
  puts "Backup folders have been created."

  f_name
end

def create_file(path, first_partner, second_partner)
  log_names = {"fwd_logfile" => "", "rev_logfile" => ""}

  log_names["fwd_logfile"] << "#{path}/from#{first_partner}2#{second_partner}.log"
  log_names["rev_logfile"] << "#{path}/from#{second_partner}2#{first_partner}.log"
  puts "Going to create the log files"

  log_names.each_value {|f| File.new(f, 'w')}
  puts "Files have been created."
  log_names
end

def selector(common_data, spec_data)
  puts "Please choose the number you need:"
  common_data.each_pair {|key, value| puts "#{key} => #{value}"}

  symbol_pos = gets.chomp.to_i
  puts "Wrong number!!!" unless common_data.key?(symbol_pos)

  s_code = common_data[symbol_pos]

  spec_data[s_code] if spec_data.key?(s_code)
end

def create_working_folder(dst_path, first_side, second_side)
  dir_name = {"working_dir" => "", "backup_dir" => ""}

  dir_name["working_dir"] << "#{dst_path}/from#{first_side}2#{second_side}/"
  dir_name["backup_dir"] << "#{dst_path}/from#{first_side}2#{second_side}/backup/"
  puts "Going to create working folders"

  FileUtils::mkdir_p "#{dir_name["working_dir"]}" unless Dir.exist?("#{dir_name["working_dir"]}")
  puts "Working folders have been created: #{dir_name["working_dir"]}"
  FileUtils::mkdir_p "#{dir_name["backup_dir"]}" unless Dir.exist?("#{dir_name["backup_dir"]}")
  puts "Backup folders have been created: #{dir_name["backup_dir"]}"

  dir_name
end

def downstream_part(carrier_company, address)
  objects = {
    "hostname" => "",
    "user" => "",
    "password" => "",
    "remote_dir" => "",
    "backup_dir" => "",
    "protocol" => ""
  }

  #Downstream part
  objects["hostname"] = address
  puts "Please specify the user name for the #{carrier_company}:"
  objects["user"] = gets.chomp
  puts "Please specify the password for the #{carrier_company}:"
  objects["password"] = gets.chomp
  puts "Remote directory:"
  objects["remote_dir"] = gets.chomp
  puts "Remote backup directory:"
  objects["backup_dir"] = gets.chomp
=begin
  puts "Please chose the protocol ftp/sftp/local. "
  prot = gets.chomp
  puts "Wrong input" unless prot.downcase.match(/ftp|sftp|local/)
  objects["protocol"] = prot
=end
  if carrier_company.match(/JDA/)
    objects["protocol"] = 'local'
  else
    puts "Please chose the protocol ftp/sftp/local. "
    prot = gets.chomp
    puts "Wrong input" unless prot.downcase.match(/ftp|sftp/)
    objects["protocol"] = prot
  end
  objects
end

def upstream_part(carrier_company, address)
  objects = {
    "hostname" => "",
    "user" => "",
    "password" => "",
    "dst_dir" => "",
    "protocol" => ""
  }

  #Upstream part
  objects["hostname"] = address
  puts "Please specify the user name for the #{carrier_company}:"
  objects["user"] = gets.chomp
  puts "Please specify the password for the #{carrier_company}:"
  objects["password"] = gets.chomp
  puts "Remote directory:"
  objects["dst_dir"] = gets.chomp

  puts "Please chose the protocol ftp/sftp/local. "
  prot = gets.chomp
  puts "Wrong input" unless prot.downcase.match(/ftp|sftp|local/)
  objects["protocol"] = prot

  objects
end

