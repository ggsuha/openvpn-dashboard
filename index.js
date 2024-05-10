const { exec } = require('child_process');
const express = require('express');
const fs = require('fs');
const path = require('path');
require('dotenv').config()

const byteSize = require('byte-size')
const app = express();

app.use(express.static(path.join(__dirname, 'public')));
app.set('view engine', 'pug');

app.get('/', (req, res) => {
  res.render('home', { title: 'Timedoor VPN' });
});

app.get('/clients', (req, res) => {
  const path = process.env.FILEPATH;
  const extension = process.env.EXTENSION;

  const files = fs.readdirSync(path).filter(file => [].includes(file) === false);
  const clients = files.map(file => file.replace(extension, ''));

  res.render('clients', { title: 'Timedoor VPN - Clients', clients });
});

app.get('/connections', (req, res) => {
  const logFile = process.env.LOGFILE;
  fs.readFile(logFile, 'utf8', (err, data) => {
    if (err) {
      console.error('Error reading file:', err);
      res.status(500).send('Error reading file');
      return;
    }

    const connections = parseLogData(data);
    res.render('connections', { title: 'Timedoor VPN - Connection List', connections });
  });
});

app.get('/create', handleProcessExecution(process.env.CREATE_SCRIPT_LOCATION, 'commonName'));
app.get('/delete', handleProcessExecution(process.env.REVOKE_SCRIPT_LOCATION, 'commonName', 'password'));

app.listen(3000, () => {
  console.log('Server started on port 3000');
});

function parseLogData(data) {
  const lines = data.split('\n');
  let headers = [];
  const clientList = [];

  for (const line of lines) {
    if (line.startsWith('HEADER')) {
      headers = line.split(',').slice(2);
    } else if (line.startsWith('CLIENT_LIST')) {
      const values = line.split(',').slice(1);
      const client = {};
      for (let i = 0; i < headers.length; i++) {
        client[headers[i]] = values[i];

        if (headers[i] === 'Bytes Received' || headers[i] === 'Bytes Sent') {
          const data = byteSize(values[i]);

          client[headers[i]] = `${data.value} ${data.unit}`;
        }

        if (headers[i] === 'Connected Since (time_t)') {
          client['Connected Since'] = new Date(values[i] * 1000).toLocaleString('en-US', { timeZone: 'Asia/Makassar' });
        }
      }
      clientList.push(client);
    }
  }

  return clientList;
}

function handleProcessExecution(scriptPath, ...queryParams) {
  return (req, res) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const scriptArgs = queryParams.map(param => req.query[param]).join(' ');
    const child = exec(`${scriptPath} ${scriptArgs}`, { shell: '/bin/bash' });

    child.stdout.on('data', (data) => {
      res.write(`data: ${data}\n\n`);
    });

    child.stderr.on('data', (data) => {
      res.write(`data: ${data}\n\n`);
    });

    child.on('exit', (code) => {
      res.write(`data: Command finished with exit code ${code}\n\n`);
      res.end();
    });
  };
}