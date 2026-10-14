import bcrypt from 'bcrypt';
import { pool } from '../config/db';
import type { PoolClient } from 'pg';
import { ErrorNegocio } from './movimientos.service';

export async function listarUsuarios() {
  const result = await pool.query(
    `SELECT u.id_usuario, u.nombre, u.apellido, u.celular, u.correo,
            u.activo, r.nombre AS rol,
            COALESCE((
              SELECT json_agg(json_build_object('id_ministerio', mi.id_ministerio, 'ministerio', mi.nombre, 'cargo', rc.nombre)
                              ORDER BY mi.nombre)
              FROM membresias m
              JOIN ministerios mi ON mi.id_ministerio = m.id_ministerio
              JOIN roles rc ON rc.id_rol = m.id_rol
              WHERE m.id_usuario = u.id_usuario
                AND m.activo = TRUE AND mi.es_privado = FALSE
            ), '[]'::json) AS cargos
     FROM usuarios u
     JOIN roles r ON r.id_rol = u.id_rol_sistema
     ORDER BY u.nombre`
  );
  return result.rows;
}

export async function crearUsuario(datos: {
  nombre: string;
  apellido: string;
  celular?: string;
  correo: string;
  password: string;
  rol: 'admin' | 'pastor' | 'miembro';
}) {
  const hash = await bcrypt.hash(datos.password, 10);
  const result = await pool.query(
    `INSERT INTO usuarios (nombre, apellido, celular, correo, password_hash, id_rol_sistema)
     VALUES ($1, $2, $3, $4, $5, (SELECT id_rol FROM roles WHERE nombre = $6))
     RETURNING id_usuario, nombre, apellido, celular, correo, activo`,
    [datos.nombre, datos.apellido, datos.celular ?? null, datos.correo, hash, datos.rol]
  );
  return { ...result.rows[0], rol: datos.rol };
}

export async function editarUsuario(
  id: number,
  datos: { nombre: string; apellido: string; celular?: string; activo: boolean }
) {
  const result = await pool.query(
    `UPDATE usuarios
     SET nombre = $2, apellido = $3, celular = $4, activo = $5
     WHERE id_usuario = $1
     RETURNING id_usuario, nombre, apellido, celular, correo, activo`,
    [id, datos.nombre, datos.apellido, datos.celular ?? null, datos.activo]
  );
  return result.rows[0] ?? null;
}

async function enTransaccion<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const resultado = await fn(client);
    await client.query('COMMIT');
    return resultado;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function asignarMembresia(
  idUsuario: number,
  idMinisterio: number,
  rol: 'presidente' | 'secretario' | 'tesorero' | 'integrante',
  idHechoPor: number
) {
  return enTransaccion(async (client) => {
    const min = await client.query(
      'SELECT es_privado FROM ministerios WHERE id_ministerio = $1 AND activo = TRUE',
      [idMinisterio]
    );
    if (!min.rows[0]) throw new ErrorNegocio(404, 'Ministerio no encontrado');
    if (min.rows[0].es_privado) {
      throw new ErrorNegocio(403, 'No se pueden gestionar cargos de un ministerio privado');
    }

    const previa = await client.query(
      `SELECT m.activo, r.nombre AS cargo
       FROM membresias m JOIN roles r ON r.id_rol = m.id_rol
       WHERE m.id_usuario = $1 AND m.id_ministerio = $2
       FOR UPDATE OF m`,
      [idUsuario, idMinisterio]
    );
    const anterior = previa.rows[0];

    const r = await client.query(
      `INSERT INTO membresias (id_usuario, id_ministerio, id_rol)
       VALUES ($1, $2, (SELECT id_rol FROM roles WHERE nombre = $3 AND ambito = 'ministerio'))
       ON CONFLICT (id_usuario, id_ministerio)
       DO UPDATE SET id_rol = EXCLUDED.id_rol, activo = TRUE
       RETURNING id_membresia, id_usuario, id_ministerio, activo`,
      [idUsuario, idMinisterio, rol]
    );

    const sinCambio = anterior && anterior.activo && anterior.cargo === rol;
    if (!sinCambio) {
      const accion = anterior && anterior.activo ? 'cambiado' : 'asignado';
      await client.query(
        `INSERT INTO membresias_his
           (id_usuario, id_ministerio, accion, cargo_anterior, cargo_nuevo, id_hecho_por)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [idUsuario, idMinisterio, accion,
         anterior && anterior.activo ? anterior.cargo : null, rol, idHechoPor]
      );
    }
    return { ...r.rows[0], rol };
  });
}

export async function revocarMembresia(
  idUsuario: number,
  idMinisterio: number,
  idHechoPor: number
) {
  return enTransaccion(async (client) => {
    const actual = await client.query(
      `SELECT m.id_membresia, r.nombre AS cargo, mi.es_privado
       FROM membresias m
       JOIN roles r ON r.id_rol = m.id_rol
       JOIN ministerios mi ON mi.id_ministerio = m.id_ministerio
       WHERE m.id_usuario = $1 AND m.id_ministerio = $2 AND m.activo = TRUE
       FOR UPDATE OF m`,
      [idUsuario, idMinisterio]
    );
    const mem = actual.rows[0];
    if (!mem) throw new ErrorNegocio(404, 'El usuario no tiene un cargo activo en ese ministerio');
    if (mem.es_privado) {
      throw new ErrorNegocio(403, 'No se pueden gestionar cargos de un ministerio privado');
    }

    await client.query('UPDATE membresias SET activo = FALSE WHERE id_membresia = $1', [
      mem.id_membresia,
    ]);
    await client.query(
      `INSERT INTO membresias_his
         (id_usuario, id_ministerio, accion, cargo_anterior, id_hecho_por)
       VALUES ($1, $2, 'revocado', $3, $4)`,
      [idUsuario, idMinisterio, mem.cargo, idHechoPor]
    );
    return { id_usuario: idUsuario, id_ministerio: idMinisterio, cargo_revocado: mem.cargo };
  });
}

export async function cambiarPassword(id: number, password: string) {
  const hash = await bcrypt.hash(password, 10);
  const result = await pool.query(
    'UPDATE usuarios SET password_hash = $2 WHERE id_usuario = $1 RETURNING id_usuario',
    [id, hash]
  );
  return result.rows.length > 0;
}