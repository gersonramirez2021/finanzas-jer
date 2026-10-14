import { Request, Response } from 'express';
import { z } from 'zod';
import {
  ErrorNegocio,
  registrarMovimiento,
  listarMovimientos,
  editarMovimiento,
  decidirMovimiento,
} from '../services/movimientos.service';

const fechaSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Formato AAAA-MM-DD');

const registrarSchema = z.object({
  idMinisterio: z.number().int().positive(),
  idCategoria: z.number().int().positive(),
  tipo: z.enum(['ingreso', 'egreso']),
  monto: z.number().positive().max(9999999999),
  descripcion: z.string().trim().max(500).optional(),
  fecha: fechaSchema.optional(),
  evidenciaUrl: z.string().trim().max(500).optional(),
});

const editarSchema = z.object({
  idCategoria: z.number().int().positive(),
  monto: z.number().positive().max(9999999999),
  descripcion: z.string().trim().max(500).optional(),
  fecha: fechaSchema,
  evidenciaUrl: z.string().trim().max(500).optional(),
});

const decisionSchema = z.object({
  decision: z.enum(['aprobado', 'rechazado']),
});

function manejarError(error: unknown, res: Response) {
  if (error instanceof ErrorNegocio) {
    return res.status(error.status).json({ error: error.message });
  }
  console.error(error);
  return res.status(500).json({ error: 'Error interno del servidor' });
}

export async function registrarController(req: Request, res: Response) {
  const datos = registrarSchema.safeParse(req.body);
  if (!datos.success) return res.status(400).json({ error: 'Datos inválidos' });

  try {
    const mov = await registrarMovimiento(req.usuario!.id, req.usuario!.rol, datos.data);
    return res.status(201).json(mov);
  } catch (error) {
    return manejarError(error, res);
  }
}

export async function listarController(req: Request, res: Response) {
  const idMinisterio = Number(req.query.idMinisterio);
  const estado = typeof req.query.estado === 'string' ? req.query.estado : undefined;
  if (!Number.isInteger(idMinisterio) || idMinisterio <= 0) {
    return res.status(400).json({ error: 'idMinisterio requerido' });
  }

  try {
    const lista = await listarMovimientos(req.usuario!.id, req.usuario!.rol, idMinisterio, estado);
    return res.json(lista);
  } catch (error) {
    return manejarError(error, res);
  }
}

export async function editarController(req: Request, res: Response) {
  const id = Number(req.params.id);
  const datos = editarSchema.safeParse(req.body);
  if (!Number.isInteger(id) || !datos.success) {
    return res.status(400).json({ error: 'Datos inválidos' });
  }

  try {
    const mov = await editarMovimiento(req.usuario!.id, req.usuario!.rol, id, datos.data);
    return res.json(mov);
  } catch (error) {
    return manejarError(error, res);
  }
}

export async function decidirController(req: Request, res: Response) {
  const id = Number(req.params.id);
  const datos = decisionSchema.safeParse(req.body);
  if (!Number.isInteger(id) || !datos.success) {
    return res.status(400).json({ error: 'Datos inválidos' });
  }

  try {
    const mov = await decidirMovimiento(req.usuario!.id, req.usuario!.rol, id, datos.data.decision);
    return res.json(mov);
  } catch (error) {
    return manejarError(error, res);
  }
}