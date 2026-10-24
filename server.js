   const http = require('http');
   const os = require('os');

   const server = http.createServer((req, res) => {
     res.writeHead(200, { 'Content-Type': 'text/plain' });
     res.end(`Hello from ${os.hostname()} on Ubuntu\nTime: ${new Date().toISOString()}\n`);
   });

   server.listen(3000, '127.0.0.1', () => console.log('Listening on 3000'));

