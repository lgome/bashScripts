
#!/bin/bash
df -h > /tmp/mail_report.log
free -m >> /tmp/mail_report.log
mail -s "disk and RAM report" lgomez@aligntech.com < /tmp/mail_report.log

 
