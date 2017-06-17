 #!/bin/sh

 find /var/www/storage/ -name page.html -size -100k | xargs -I {} find /var/www/storage/ -samefile {} | xargs -I {} rm {}

 