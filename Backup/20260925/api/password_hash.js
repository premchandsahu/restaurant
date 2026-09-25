const bcrypt = require('bcrypt');

async function main() {
    // The await keyword is now inside an async context
    const hash = await bcrypt.hash('admin123', 10);
    console.log(hash);
}

main();