const fs = require('fs');
const repo = require('./src/modules/cafes/cafes.repository');

repo.findCafes({ price_range: '$$' })
  .then(res => fs.writeFileSync('test_out.txt', JSON.stringify(res, null, 2)))
  .catch(err => fs.writeFileSync('test_out.txt', err.stack))
  .finally(() => process.exit(0));
