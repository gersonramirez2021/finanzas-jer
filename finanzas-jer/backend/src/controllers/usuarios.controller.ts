import { Request, Response } from 'express';
import { z } from 'zod';
import {
  listarUsuarios,
  crearUsuario,
  editarUsuario,
  asignarMembresia,
  revocarMembresia,
  cambiarPassword,
} from '../services/usuarios.service';

const crearSchema = z.object({
  nombre: z.string().trim().min(2).max(80),
  apellido: z.string().trim().min(2).max(80),
  celular: z.string().trim().max(20).optional(),
  correo: z.string().trim().email().max(120),
  password: z.string().min(8).max(100),
  rol: z.enum(['admin', 'pastor', 'miembro']),
});

const editarSchema = z.object({
  nombre: z.string().trim().min(2).max(80),
  apellido: z.string().trim().min(2).max(80),
  celular: z.string().trim().max(20).optional(),
  activo: z.boolean(),
});

const membresiaSchema = z.object({
  idMinisterio: z.number().int().positive(),
  rol: z.enum(['presidente', 'secretario', 'tesorero', 'integrante']),
});

export async function listarController(_req: Request, res: Response) {
  try {
    return res.json(await listarUsuarios());
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
    const usuario = await crearUsuario(datos.data);
    return res.status(201).json(usuario);
  } catch (error: any) {
    if (error.code === '23505') {
      return res.status(409).json({ error: 'Ya existe un usuario con ese correo' });
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
    const usuario = await editarUsuario(id, datos.data);
    if (!usuario) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    return res.json(usuario);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

export async function membresiaController(req: Request, res: Response) {
  const idUsuario = Number(req.params.id);
  const datos = membresiaSchema.safeParse(req.body);
  if (!Number.isInteger(idUsuario) || !datos.success) {
    return res.status(400).json({ error: 'Datos inválidos' });
  }

  try {
    const membresia = await asignarMembresia(
      idUsuario,
      datos.data.idMinisterio,
      datos.data.rol,
      req.usuario!.id
    );
    return res.status(201).json(membresia);
  } catch (error: any) {
    if (error instanceof ErrorNegocio) {
      return res.status(error.status).json({ error: error.message });
    }
    if (error.code === '23503') {
      return res.status(404).json({ error: 'Usuario o ministerio no existe' });
    }
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

export async function revocarController(req: Request, res: Response) {
  const idUsuario = Number(req.params.id);
  const idMinisterio = Number(req.params.idMinisterio);
  if (!Number.isInteger(idUsuario) || !Number.isInteger(idMinisterio)) {
    return res.status(400).json({ error: 'Datos inválidos' });
  }

  try {
    const r = await revocarMembresia(idUsuario, idMinisterio, req.usuario!.id);
    return res.json(r);
  } catch (error) {
    if (error instanceof ErrorNegocio) {
      return res.status(error.status).json({ error: error.message });
    }
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

const passwordSchema = z.object({
  password: z.string().min(8).max(100),
});

export async function passwordController(req: Request, res: Response) {
  const id = Number(req.params.id);
  const datos = passwordSchema.safeParse(req.body);
  if (!Number.isInteger(id) || !datos.success) {
    return res.status(400).json({ error: 'La contraseña debe tener mínimo 8 caracteres' });
  }

  try {
    const ok = await cambiarPassword(id, datos.data.password);
    if (!ok) return res.status(404).json({ error: 'Usuario no encontrado' });
    return res.json({ mensaje: 'Contraseña actualizada' });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}