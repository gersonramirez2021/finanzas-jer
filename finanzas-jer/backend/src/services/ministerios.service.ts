import { pool } from '../config/db';

export async function listarMinisterios(rol: string) {
  const verPrivados = rol === 'pastor';
  const result = await pool.query(
    `SELECT id_ministerio, nombre, descripcion, es_privado, activo
     FROM ministerios
     WHERE ($1::boolean OR es_privado = FALSE)
     ORDER BY nombre`,
    [verPrivados]
  );
  return result.rows;
}

export async function crearMinisterio(nombre: string, descripcion?: string) {
  const result = await pool.query(
    `INSERT INTO ministerios (nombre, descripcion)
     VALUES ($1, $2)
     RETURNING id_ministerio, nombre, descripcion, es_privado, activo`,
    [nombre, descripcion ?? null]
  );
  return result.rows[0];
}

export async function editarMinisterio(
  id: number,
  nombre: string,
  descripcion: string | undefined,
  activo: boolean
) {
  const result = await pool.query(
    `UPDATE ministerios
     SET nombre = $2, descripcion = $3, activo = $4
     WHERE id_ministerio = $1 AND es_privado = FALSE
     RETURNING id_ministerio, nombre, descripcion, es_privado, activo`,
    [id, nombre, descripcion ?? null, activo]
  );
  return result.rows[0] ?? null;
}