const fs = require('fs');
const path = require('path');
const dir = __dirname;
const exts = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'];
const files = fs.readdirSync(dir).filter(f => exts.includes(path.extname(f).toLowerCase()));
fs.writeFileSync(path.join(dir, 'index.json'), JSON.stringify(files, null, 2));
console.log('index.json:', files);