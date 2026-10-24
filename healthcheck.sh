   #!/bin/bash
   code=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost)
   echo "$(date -Is) status=$code" >> /home/ayrus15/hello-app/health.log
