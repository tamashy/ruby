config = YAML::load(open('/home/ediuser/edi-simple-version.yml'))

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

