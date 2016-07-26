#!/usr/bin/ruby -w
require 'fileutils'
require 'yaml'

config = YAML::load(open('/mnt/bigdisk/storage-kvm/edi-simple-version.yml'))

###################################################################################################
def  working_folder_create(dst_path, first_side, second_side)
  f_name = {:dir_local => [], :backup_dir => []}

  f_name[:dir_local] << "#{dst_path}/from#{first_side}2#{second_side}" << "#{dst_path}/from#{second_side}2#{first_side}"
  f_name[:backup_dir] << "#{dst_path}/from#{second_side}2#{first_side}/backup" << "#{dst_path}/from#{first_side}2#{second_side}/backup"
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

  dir_name["working_dir"] << "#{dst_path}/from#{first_side}2#{second_side}"
  dir_name["backup_dir"] << "#{dst_path}/from#{first_side}2#{second_side}/backup"
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
  puts "Please chose the protocol ftp/sftp/local. "
  prot = gets.chomp
  puts "Wrong input" unless prot.downcase.match(/ftp|sftp|local/)
  objects["protocol"] = prot

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

###################################################################################################
conf_data = {:lfile => [], :carrier1_addr => "", :carrier2_addr => ""}

config_file = { "defaults" => {
                "log_file"  => "", 
                "backup_local" => "", 
                "dir_local" => "", 
                "regexp" => ""
                }, 
				        "down_stream" => {}, 
				        "up_stream" => {}
              }

revers_config_file = { "defaults" => {
                "log_file"  => "", 
                "backup_local" => "", 
                "dir_local" => "", 
                "regexp" => ""
                }, 
                "down_stream" => {}, 
                "up_stream" => {}
              }

path_preffix = "/tmp/ftp"
log_path_preffix = "/tmp/ftp/log"
a = config["country"]
b = config["country_code"]
c = config["brand"]
d = config["brand_code"] 
third_company = config["3plCompany"]
third_company_code = config["3pl_code"]
third_company_addrs = config["3pl_addrs"]

####################################################################################################
puts "Is it prod or preprod?"
env = gets.chomp
exit 1  unless env.downcase.match(/preprod|prod/)

puts "Is it transfer between Kering and 3PL? Y/N"
transfer_type = gets.chomp
if transfer_type.downcase.match(/y/)
  carrier1 = selector third_company, third_company_code
  conf_data[:carrier1_addr] = third_company_addrs[carrier1] if third_company_addrs.key?(carrier1) 
  carrier2 = config["JDA"]["name"]
  if env.downcase.match(/preprod/)
	  conf_data[:carrier2_addr] = config["JDA"]["preprod"]
  else env.downcase.match(/prod/)
    conf_data[:carrier2_addr] = config["JDA"]["prod"]
  end
elsif transfer_type.downcase.match(/n/)
  puts "Is it transfer between 3PLs? Y/N"
  if gets.chomp.downcase.match(/y/)
    carrier1 = selector third_company, third_company_code
    conf_data[:carrier1_addr] = third_company_addrs[carrier1] if third_company_addrs.key?(carrier1) 
    carrier2 = selector third_company, third_company_code
    conf_data[:carrier2_addr] = third_company_addrs[carrier2] if third_company_addrs.key?(carrier2) 
  else
    puts "Such transfer cannot be configured!!!"
    exit 2
  end
end

brand = selector c, d
country = selector a, b

puts brand
puts country

puts "Please specify the regular expression:"
revers_config_file["defaults"]["regexp"] = config_file["defaults"]["regexp"] << gets.chomp

FileUtils::mkdir_p path_preffix unless Dir.exist?(path_preffix) && File.directory?(path_preffix)

interface_path = "#{path_preffix}/#{brand}-#{country}-#{env}"
puts "Configuration files should be located by the following path: #{interface_path}"

puts "Log files shoud be located: #{log_path_preffix}"
FileUtils.mkdir_p(log_path_preffix) unless File.directory?(log_path_preffix) && Dir.exist?(log_path_preffix)

conf_data[:lfile] = create_file log_path_preffix, carrier1, carrier2

puts "All necessary folders and files have been created"

###################################################################################################
puts "Going to generate a deafult configuration part of configuration file for the  #{carrier1} => #{carrier2} flow direction."
conf_data["first_direction_wdir"] = create_working_folder interface_path, carrier1, carrier2

config_file["defaults"]["log_file"] = conf_data[:lfile]["fwd_logfile"]
config_file["defaults"]["dir_local"] =  conf_data["first_direction_wdir"]["working_dir"]
config_file["defaults"]["backup_local"] =  conf_data["first_direction_wdir"]["backup_dir"]

puts "Going to generate upstream and downstream configuration part for the #{carrier1} => #{carrier2} flow direction."

config_file["down_stream"] = downstream_part carrier1, conf_data[:carrier1_addr]
config_file["up_stream"] = upstream_part carrier2, conf_data[:carrier2_addr]

fwd_transfer_file = "#{conf_data["first_direction_wdir"]["working_dir"]}/from#{carrier1}2#{carrier2}.yml"

File.open(fwd_transfer_file, 'a'){|f| f << config_file.to_yaml}

###################################################################################################
puts "Going to generate a deafult configuration part of configuration file for the  #{carrier2} => #{carrier1} flow direction."
conf_data["second_direction_wdir"] = create_working_folder interface_path, carrier2, carrier1

revers_config_file["defaults"]["log_file"] = conf_data[:lfile]["rev_logfile"]
revers_config_file["defaults"]["dir_local"] =  conf_data["second_direction_wdir"]["working_dir"]
revers_config_file["defaults"]["backup_local"] =  conf_data["second_direction_wdir"]["backup_dir"]

puts "Going to generate upstream and downstream configuration part for the #{carrier2} => #{carrier1} flow direction."

revers_config_file["down_stream"]["hostname"] = config_file["up_stream"]["hostname"]
revers_config_file["down_stream"]["user"] = config_file["up_stream"]["user"]
revers_config_file["down_stream"]["password"] = config_file["up_stream"]["password"]
revers_config_file["down_stream"]["protocol"] = config_file["up_stream"]["protocol"]

puts "Please cpecify the source directory on the #{carrier2}:"
revers_config_file["down_stream"]["remote_dir"] = gets.chomp
puts "Please cpecify the backup directory on the #{carrier2} :"
revers_config_file["down_stream"]["backup_dir"] = gets.chomp

revers_config_file["up_stream"]["hostname"] = config_file["down_stream"]["hostname"]
revers_config_file["up_stream"]["user"] = config_file["down_stream"]["user"]
revers_config_file["up_stream"]["password"] = config_file["down_stream"]["password"]
revers_config_file["up_stream"]["protocol"] = config_file["down_stream"]["protocol"]

puts "Please specify remote destination directory on the #{carrier1}:"
revers_config_file["up_stream"]["dst_dir"] = gets.chomp

rev_transfer_file = "#{conf_data["second_direction_wdir"]["working_dir"]}/from#{carrier2}2#{carrier1}.yml"

File.open(rev_transfer_file, 'a'){|f| f << revers_config_file.to_yaml}

puts "Now you can add the following string to the crontab:"
puts "ruby /home/ediuser/transfer.rb #{rev_transfer_file}"
puts "ruby /home/ediuser/transfer.rb #{fwd_transfer_file}"

#puts config_file.to_yaml
#puts revers_config_file.to_yaml