const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Middleware to log requests
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url} - ${new Date().toISOString()}`);
  next();
});

// Parse JSON bodies for incoming requests
app.use(express.json());

// Health check route
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP' });
});

// Home route
app.get('/', (req, res) => {
  res.send(`
    <h1>DevOps Assignment for GTS hello again</h1>
    <p>Explore the available routes:</p>
    <ul>
      <li><a href="/about">About</a></li>
      <li><a href="/contact">Contact</a></li>
    </ul>
  `);
});

// About route
app.get('/about', (req, res) => {
  res.json({
    message: 'This is a Node.js web application for the DevOps Assignment for GTS , hello from about again',
    version: '1.0.0',
  });
});

// Contact route
app.get('/contact', (req, res) => {
  res.json({
    email: 'support@gts.com',
    phone: '123-456-7890',
  });
});

// A POST route to handle contact form submissions
app.post('/contact', (req, res) => {
  const { name, message } = req.body;

  if (!name || !message) {
    return res.status(400).json({ error: 'Name and message are required.' });
  }

  res.status(200).json({
    message: 'Thank you for reaching out!',
    receivedData: { name, message },
  });
});

// Handle 404 errors
app.use((req, res) => {
  res.status(404).send('404 - Page Not Found');
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send('Something went wrong! Try again later.');
});

// Export the app for testing
module.exports = app;

// Start the server only if this file is run directly
if (require.main === module) {
  app.listen(port, () => {
    console.log(`App is running on http://localhost:${port}`);
  });
}
