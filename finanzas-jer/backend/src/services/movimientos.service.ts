import type { PoolClient } from 'pg';
import { pool } from '../config/db';
import { cargoEnMinisterio, puedeVer } from './acceso.service';

export class ErrorNegocio extends Error {
  status: number;
  constructor(status: number, mensaje: string) {
    super(mensaje);
    this.status = status;
  }
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

// En ministerios normales se exige el cargo indicado.
// En el privado (Pastoral) solo el pastor puede registrar y aprobar.
async function tieneCargo(
  idUsuario: number,
  rol: string,
  idMinisterio: number,
  cargoRequerido: 'tesorero' | 'presidente'
) {
  const m = await pool.query(
    'SELECT es_privado FROM ministerios WHERE id_ministerio = $1 AND activo = TRUE',
    [idMinisterio]
  );
  if (!m.rows[0]) throw new ErrorNegocio(404, 'Ministerio no encontrado');
  if (m.rows[0].es_privado) return rol === 'pastor';
  return (await cargoEnMinisterio(idUsuario, idMinisterio)) === cargoRequerido;
}

export async function registrarMovimiento(
  idUsuario: number,
  rol: string,
  d: {
    idMinisterio: number;
    idCategoria: number;
    tipo: 'ingreso' | 'egreso';
    monto: number;
    descripcion?: string;
    fecha?: string;
    evidenciaUrl?: string;
  }
) {
  if (!(await tieneCargo(idUsuario, rol, d.idMinisterio, 'tesorero'))) {
    throw new ErrorNegocio(403, 'Solo el tesorero puede registrar movimientos');
  }

  const cat = await pool.query(
    `SELECT 1 FROM categorias
     WHERE id_categoria = $1 AND tipo = $2 AND activa = TRUE
       AND (id_ministerio IS NULL OR id_ministerio = $3)`,
    [d.idCategoria, d.tipo, d.idMinisterio]
  );
  if (!cat.rows[0]) throw new ErrorNegocio(400, 'Categoría inválida para este movimiento');

  return enTransaccion(async (client) => {
    const r = await client.query(
      `INSERT INTO movimientos
         (id_ministerio, id_categoria, tipo, monto, descripcion, fecha,
          evidencia_url, id_registrado_por)
       VALUES ($1, $2, $3, $4, $5, COALESCE($6::date, CURRENT_DATE), $7, $8)
       RETURNING *`,
      [d.idMinisterio, d.idCategoria, d.tipo, d.monto, d.descripcion ?? null,
       d.fecha ?? null, d.evidenciaUrl ?? null, idUsuario]
    );
    await client.query(
      `INSERT INTO movimientos_his (id_movimiento, accion, id_usuario)
       VALUES ($1, 'creado', $2)`,
      [r.rows[0].id_movimiento, idUsuario]
    );
    return r.rows[0];
  });
}

export async function listarMovimientos(
  idUsuario: number,
  rol: string,
  idMinisterio: number,
  estado?: string
) {
  if (!(await puedeVer(idUsuario, rol, idMinisterio))) {
    throw new ErrorNegocio(403, 'No tienes acceso a este ministerio');
  }
  const r = await pool.query(
    `SELECT mv.id_movimiento, mv.tipo, mv.monto, mv.descripcion, mv.fecha,
            mv.estado, mv.evidencia_url, c.nombre AS categoria,
            u.nombre || ' ' || u.apellido AS registrado_por
     FROM movimientos mv
     JOIN categorias c ON c.id_categoria = mv.id_categoria
     JOIN usuarios u ON u.id_usuario = mv.id_registrado_por
     WHERE mv.id_ministerio = $1 AND ($2::text IS NULL OR mv.estado = $2)
     ORDER BY mv.fecha DESC, mv.id_movimiento DESC`,
    [idMinisterio, estado ?? null]
  );
  return r.rows;
}

export async function editarMovimiento(
  idUsuario: number,
  rol: string,
  idMovimiento: number,
  d: {
    idCategoria: number;
    monto: number;
    descripcion?: string;
    fecha: string;
    evidenciaUrl?: string;
  }
) {
  return enTransaccion(async (client) => {
    const actual = await client.query(
      'SELECT * FROM movimientos WHERE id_movimiento = $1 FOR UPDATE',
      [idMovimiento]
    );
    const mov = actual.rows[0];
    if (!mov) throw new ErrorNegocio(404, 'Movimiento no encontrado');

    if (!(await tieneCargo(idUsuario, rol, mov.id_ministerio, 'tesorero'))) {
      throw new ErrorNegocio(403, 'Solo el tesorero puede editar movimientos');
    }
    if (!['pendiente', 'rechazado'].includes(mov.estado)) {
      throw new ErrorNegocio(409, 'Solo se pueden editar movimientos pendientes o rechazados');
    }

    const cat = await client.query(
      `SELECT 1 FROM categorias
       WHERE id_categoria = $1 AND tipo = $2 AND activa = TRUE
         AND (id_ministerio IS NULL OR id_ministerio = $3)`,
      [d.idCategoria, mov.tipo, mov.id_ministerio]
    );
    if (!cat.rows[0]) throw new ErrorNegocio(400, 'Categoría inválida para este movimiento');

    const r = await client.query(
      `UPDATE movimientos
       SET id_categoria = $2, monto = $3, descripcion = $4, fecha = $5,
           evidencia_url = $6, estado = 'pendiente',
           id_aprobado_por = NULL, fecha_aprobacion = NULL
       WHERE id_movimiento = $1
       RETURNING *`,
      [idMovimiento, d.idCategoria, d.monto, d.descripcion ?? null, d.fecha,
       d.evidenciaUrl ?? null]
    );
    await client.query(
      `INSERT INTO movimientos_his (id_movimiento, accion, id_usuario, datos_anteriores)
       VALUES ($1, 'editado', $2, $3)`,
      [idMovimiento, idUsuario, JSON.stringify(mov)]
    );
    return r.rows[0];
  });
}

export async function decidirMovimiento(
  idUsuario: number,
  rol: string,
  idMovimiento: number,
  decision: 'aprobado' | 'rechazado'
) {
  return enTransaccion(async (client) => {
    const actual = await client.query(
      'SELECT * FROM movimientos WHERE id_movimiento = $1 FOR UPDATE',
      [idMovimiento]
    );
    const mov = actual.rows[0];
    if (!mov) throw new ErrorNegocio(404, 'Movimiento no encontrado');

    if (!(await tieneCargo(idUsuario, rol, mov.id_ministerio, 'presidente'))) {
      throw new ErrorNegocio(403, 'Solo el presidente puede aprobar o rechazar');
    }
    if (mov.estado !== 'pendiente') {
      throw new ErrorNegocio(409, 'El movimiento ya fue revisado');
    }

    const r = await client.query(
      `UPDATE movimientos
       SET estado = $2, id_aprobado_por = $3, fecha_aprobacion = NOW()
       WHERE id_movimiento = $1
       RETURNING *`,
      [idMovimiento, decision, idUsuario]
    );
    await client.query(
      `INSERT INTO movimientos_his (id_movimiento, accion, id_usuario, datos_anteriores)
       VALUES ($1, $2, $3, $4)`,
      [idMovimiento, decision, idUsuario, JSON.stringify(mov)]
    );
    return r.rows[0];
  });
}