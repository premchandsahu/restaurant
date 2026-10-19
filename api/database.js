const mysql = require('mysql2/promise');

class Database {
    constructor() {
      if (!Database.instance) {
            this.pool = mysql.createPool({
                host: '193.203.184.196',
                user: 'u310194916_restaurant_pos',
                password: 'Restaurant_pos@123',
                database: 'u310194916_restaurant_pos'
            });
            Database.instance = this;


            
        }
       

        /* if (!Database.instance) {
            this.pool = mysql.createPool({
                host: 'localhost',
                user: 'root',
                password: 'MYSQLPrem@1977',
                database: 'rest'
            });
            Database.instance = this;


            
        }
            */
        return Database.instance;
    }

    async getConnection() {
        try {
            return await this.pool.getConnection();
        } catch (error) {
            console.error('Error getting connection from the pool:', error);
            throw error;
        }
    }
}

module.exports = new Database();


/*
const mysql = require('mysql2');
const db = mysql.createConnection({ host: '193.203.184.196',
                user: 'u310194916_restaurant_pos',
                password: 'Restaurant_pos@123',
                database: 'u310194916_restaurant_pos' });

module.exports = db;
*/