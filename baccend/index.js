const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
let number = 0;

app.get('/increment', (req, res) => {
  number++;
  res.json({ number });
});

const port = 3000;
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});