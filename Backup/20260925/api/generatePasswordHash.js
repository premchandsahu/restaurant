const bcrypt = require('bcrypt');

async function generate() {
    const password = 'Test@123';

    const hash = await bcrypt.hash(password, 10);

    console.log("--->"+hash+"<---");
}

generate();