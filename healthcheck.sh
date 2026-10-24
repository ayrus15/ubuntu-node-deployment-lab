   #!/bin/bash
   code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
   echo "$(date -Is) status=$code" >> /home/ayrus15/hello-app/health.log
