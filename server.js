   const http = require('http');
   const os = require('os');
   const { Pool } = require('pg');

   const pool = new Pool({ connectionString: process.env.DATABASE_URL });

   const server = http.createServer(async (req, res) => {
     try {
       await pool.query('INSERT INTO visits (path) VALUES ($1)', [req.url]);
       const { rows } = await pool.query('SELECT count(*) AS n FROM visits');
       res.writeHead(200, { 'Content-Type': 'text/plain' });
       res.end(`Hello from ${os.hostname()} on Ubuntu\nVisits recorded: ${rows[0].n}\n`);
     } catch (err) {
       console.error(err);
       res.writeHead(500, { 'Content-Type': 'text/plain' });
       res.end('Database error\n');
     }
   });

   server.listen(3000, '127.0.0.1', () => console.log('Listening on 3000'));
