'use strict';

const { getPool } = require('./db');

const SELECT_COLUMNS =
  'id, name, seats, status, created_at AS createdAt, updated_at AS updatedAt';

async function listTables() {
  const [rows] = await getPool().query(
    `SELECT ${SELECT_COLUMNS} FROM restaurant_tables ORDER BY id ASC`
  );
  return rows;
}

async function getTable(id) {
  const [rows] = await getPool().query(
    `SELECT ${SELECT_COLUMNS} FROM restaurant_tables WHERE id = :id`,
    { id }
  );
  return rows.length ? rows[0] : null;
}

async function createTable({ name, seats }) {
  const [result] = await getPool().query(
    'INSERT INTO restaurant_tables (name, seats) VALUES (:name, :seats)',
    { name, seats: seats == null ? 2 : seats }
  );
  return getTable(result.insertId);
}

async function flipTable(id) {
  const [result] = await getPool().query(
    `UPDATE restaurant_tables
       SET status = IF(status = 'available', 'occupied', 'available')
     WHERE id = :id`,
    { id }
  );
  if (result.affectedRows === 0) {
    return null;
  }
  return getTable(id);
}

async function deleteTable(id) {
  const [result] = await getPool().query(
    'DELETE FROM restaurant_tables WHERE id = :id',
    { id }
  );
  return result.affectedRows > 0;
}

module.exports = {
  listTables,
  getTable,
  createTable,
  flipTable,
  deleteTable,
};
