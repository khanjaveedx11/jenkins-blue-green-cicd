const http = require('http');

const port = process.env.PORT || 3000;
const color = process.env.DEPLOYMENT_COLOR || 'local';
const version = process.env.APP_VERSION || 'dev';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'healthy', deployment: color, version }));
  }

  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <html>
      <head><title>Blue-Green CI/CD</title></head>
      <body style="font-family:Arial;text-align:center;margin-top:80px">
        <h1>Blue-Green Deployment</h1>
        <h2>Active environment: ${color.toUpperCase()}</h2>
        <p>Version: ${version}</p>
        <p>Deployed with GitHub → Jenkins → Docker → AWS EC2 → Nginx</p>
      </body>
    </html>
  `);
});

server.listen(port, '0.0.0.0', () => {
  console.log(`App running on port ${port} (${color}, ${version})`);
});
