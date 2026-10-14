import { Request, Response } from 'express';
import { z } from 'zod';
import {
  listarMinisterios,
  crearMinisterio,
  editarMinisterio,
} from '../services/ministerios.service';

const crearSchema = z.object({
  nombre: z.string().trim().min(2).max(100),
  descripcion: z.string().trim().max(500).optional(),
});

const editarSchema = crearSchema.extend({
  activo: z.boolean(),
});

export async function listarController(req: Request, res: Response) {
  try {
    const ministerios = await listarMinisterios(req.usuario!.rol);
    return res.json(ministerios);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

export async function crearController(req: Request, res: Response) {
  const datos = crearSchema.safeParse(req.body);
  if (!datos.success) {
    return res.status(400).json({ error: 'Datos inválidos' });
  }

  try {
    const ministerio = await crearMinisterio(datos.data.nombre, datos.data.descripcion);
    return res.status(201).json(ministerio);
  } catch (error: any) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un ministerio con ese nombre' });
    }
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

export async function editarController(req: Request, res: Response) {
  const id = Number(req.params.id);
  const datos = editarSchema.safeParse(req.body);
  if (!Number.isInteger(id) || !datos.success) {
    return res.status(400).json({ error: 'Datos inválidos' });
  }

  try {
    const ministerio = await editarMinisterio(
      id,
      datos.data.nombre,
      datos.data.descripcion,
      datos.data.activo
    );
    if (!ministerio) {
      return res.status(404).json({ error: 'Ministerio no encontrado' });
    }
    return res.json(ministerio);
  } catch (error: any) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un ministerio con ese nombre' });
    }
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}