# project EDI
This is a ruby based simple tranfer solution between FTP/SFTP servers.
The main purpose was to set up file transfer with AS/400 systems.

## Getting Started
This script was written from pretty old system and was tested only on RHEL5 and ruby 2.3.
Script operates with down_stream and up_stream variables.
down_stream - where you want to get files from.
up_stream - where you want to store files to.


### Prerequisites
Make sure that you have ruby installed.
Also you have to set up configuration file in YAML format.

### Configuration
Set up YAML configuration file and put in anywhere you'd like to
Here's an example:
```
---
defaults:
  log_file: "/var/log/edi/SFTP2FTP/fromSFTP2FTP.log"          # Where edi will store it's log files
  backup_local: "/home/ftp/SFTP2FTP/fromSFTP2FTP/backup/"     # Where edi will store backups
  dir_local: "/home/ftp/SFTP2FTP/fromSFTP2FTP"                # Where edi will store files during transfer
  regexp: "^TST001"                                           # Regexp to match files
down_stream:
  hostname: sftp.example.com                                 
  user: user.sftp
  password: password.sftp
  remote_dir: "/sftp_folder/IMPORT"
  backup_dir: "/sftp_folder/ARCHIVE"
  protocol: sftp
up_stream:
  hostname: ftp.myexample.com
  user: user.ftp
  password: password.ftp
  dst_dir: "/ftp_folder/export"
  protocol: ftp
  ```
  
### Arguments
Edi supports couple of arguments to pass:
``` 
[ediuser@server1:~]$ ruby transfer.rb
Usage: transfer.rb CONFIG.YML [options]

This is a EDI transfer script
Specify full path to configuration file in YAML
By default scropt is downloading files asyncroneously

Options
    -v, --verbose                    Turn on verbose output
    -d, --debug-ssh                  Turn on sftp connection debug
    -s, --single                     Download files in single mode one-by-one, synchroneously
    -n, --no-remove                  Dont remove any files
    -h, --help                       Displays Help
```

### Scheduling transfers
Just create a cron job, from example to check and transfer files from SFTP to FTP like in example above, you could use:
```
*/7 * * * * ruby /home/bin/transfer.rb /home/ftp/SFTP2FTP/fromSFTP2FTP.yml
```

If you want to set tranfer in single sync mode, use -s key:
```
*/7 * * * * ruby /home/bin/transfer.rb /home/ftp/SFTP2FTP/fromSFTP2FTP.yml -s
```

If your dont want to remove any files from remote SFTP server, use -n key:
*/7 * * * * ruby /home/bin/transfer.rb /home/ftp/SFTP2FTP/fromSFTP2FTP.yml -n

### Troubleshooting
For troubleshooting, execute script with -v key:
```
ruby /home/bin/transfer.rb /home/ftp/SFTP2FTP/fromSFTP2FTP.yml -v
```

For even more in-depth research, pass -d key to turn on SSH connection debug:

```
ruby /home/bin/transfer.rb /home/ftp/SFTP2FTP/fromSFTP2FTP.yml -v -d
```
