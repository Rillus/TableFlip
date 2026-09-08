'use strict';

const CREATE_TABLES_SQL = `
  CREATE TABLE IF NOT EXISTS restaurant_tables (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    seats INT UNSIGNED NOT NULL DEFAULT 2,
    status ENUM('available', 'occupied') NOT NULL DEFAULT 'available',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_restaurant_tables_name (name)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
`;

async function createSchema(connection) {
  await connection.query(CREATE_TABLES_SQL);
}

async function resetSchema(connection) {
  await connection.query('DROP TABLE IF EXISTS restaurant_tables;');
  await createSchema(connection);
}

module.exports = { CREATE_TABLES_SQL, createSchema, resetSchema };
