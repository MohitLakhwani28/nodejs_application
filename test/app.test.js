const request = require('supertest'); 
const app = require('../index'); // Adjust path if necessary

describe('GET /health', () => {
  it('should return a status of UP', async () => {
    const { expect } = await import('chai'); // Dynamic import
    const res = await request(app).get('/health');
    expect(res.statusCode).to.equal(200);
    expect(res.body).to.have.property('status', 'UP');
  });
});

describe('GET /', () => {
  it('should return the homepage', async () => {
    const { expect } = await import('chai'); // Dynamic import
    const res = await request(app).get('/');
    expect(res.statusCode).to.equal(200);
    expect(res.text).to.contain('DevOps Assignment for GTS');
  });
});
