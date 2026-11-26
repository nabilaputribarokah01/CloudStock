import os
import psycopg
from psycopg.rows import dict_row
from flask import Flask, jsonify, request

app = Flask(__name__)


def connect():
    return psycopg.connect(host=os.environ['DB_HOST'], dbname='inventory',
                           user='cloudstock', password=os.environ['DB_PASSWORD'],
                           row_factory=dict_row, connect_timeout=5)


def init_db():
    with connect() as conn:
        conn.execute('''CREATE TABLE IF NOT EXISTS items (
            id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            quantity INTEGER NOT NULL CHECK (quantity >= 0),
            location VARCHAR(100) NOT NULL
        )''')


def validate():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return None
    name, qty, location = data.get('name'), data.get('quantity'), data.get('location')
    if not isinstance(name, str) or not 1 <= len(name.strip()) <= 100:
        return None
    if type(qty) is not int or not 0 <= qty <= 2147483647:
        return None
    if not isinstance(location, str) or not 1 <= len(location.strip()) <= 100:
        return None
    return name.strip(), qty, location.strip()


@app.errorhandler(psycopg.Error)
def database_error(error):
    app.logger.error('Database operation failed: %s', type(error).__name__)
    return jsonify(error='Database unavailable'), 503


@app.get('/health')
def health():
    with connect() as conn:
        conn.execute('SELECT 1').fetchone()
    return jsonify(status='ok', database='connected')


@app.post('/items')
def create():
    values = validate()
    if values is None:
        return jsonify(error='Valid name, quantity and location required'), 400
    with connect() as conn:
        item = conn.execute('INSERT INTO items (name, quantity, location) VALUES (%s, %s, %s) RETURNING *', values).fetchone()
    return jsonify(item), 201


@app.get('/items')
def read():
    with connect() as conn:
        items = conn.execute('SELECT * FROM items ORDER BY id').fetchall()
    return jsonify(items)


@app.put('/items/<int:item_id>')
def update(item_id):
    values = validate()
    if values is None:
        return jsonify(error='Valid name, quantity and location required'), 400
    with connect() as conn:
        item = conn.execute('UPDATE items SET name=%s, quantity=%s, location=%s WHERE id=%s RETURNING *', (*values, item_id)).fetchone()
    return (jsonify(item), 200) if item else (jsonify(error='Item not found'), 404)


@app.delete('/items/<int:item_id>')
def delete(item_id):
    with connect() as conn:
        item = conn.execute('DELETE FROM items WHERE id=%s RETURNING id', (item_id,)).fetchone()
    return (jsonify(deleted=item_id), 200) if item else (jsonify(error='Item not found'), 404)


if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=8080)
