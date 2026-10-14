import { pool } from '../config/db';

// Devuelve el cargo del usuario en el ministerio ('tesorero', 'presidente', etc.) o null
export async function cargoEnMinisterio(idUsuario: number, idMinisterio: number) {
  const result = await pool.query(
    `SELECT r.nombre AS cargo
     FROM membresias m
     JOIN roles r ON r.id_rol = m.id_rol
     WHERE m.id_usuario = $1 AND m.id_ministerio = $2 AND m.activo = TRUE`,
    [idUsuario, idMinisterio]
  );
  return (result.rows[0]?.cargo as string) ?? null;
}

// ¿Puede este usuario VER las finanzas del ministerio?
export async function puedeVer(idUsuario: number, rol: string, idMinisterio: number) {
  const m = await pool.query(
    'SELECT es_privado FROM ministerios WHERE id_ministerio = $1',
    [idMinisterio]
  );
  if (!m.rows[0]) return false;

  if (rol === 'pastor') return true;
  if (rol === 'admin') return !m.rows[0].es_privado;

  return (await cargoEnMinisterio(idUsuario, idMinisterio)) !== null;
}