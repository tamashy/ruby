#!/usr/bin/env ruby 
require 'fileutils'
require 'yaml'
require_relative 'edi-parts/creation_part_methods'

config = YAML::load(open('/home/ediuser/edi-simple-version.yml'))

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

path_preffix = "/home/ftp"
log_path_preffix = "/home/logs/edi"
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

if env.match(/^prod/)
  log_path = log_path_preffix + "/" + "prod" + "/" + "#{brand}-#{country}-#{env}"
else
  log_path = log_path_preffix + "/" + "preprod" + "/" + "#{brand}-#{country}-#{env}"
end 

puts "Log files shoud be located: #{log_path}"
FileUtils.mkdir_p(log_path) unless File.directory?(log_path) && Dir.exist?(log_path)

conf_data[:lfile] = create_file log_path, carrier1, carrier2

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
puts "Do not forget to create FTP user account for the flow:"
puts "ftpasswd --stdin --passwd --name=username --file=/etc/lbn/proftpd/conf/ftpd.passwd --home /path to the home dir/ --shell /bin/bash --uid=10017 --gid=10017"

#puts config_file.to_yaml
#puts revers_config_file.to_yaml
