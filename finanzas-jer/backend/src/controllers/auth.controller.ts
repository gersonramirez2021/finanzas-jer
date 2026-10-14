import { Request, Response } from 'express';
import { z } from 'zod';
import { login } from '../services/auth.service';
import { pool } from '../config/db';

const loginSchema = z.object({
  correo: z.string().email(),
  password: z.string().min(1),
});

export async function loginController(req: Request, res: Response) {
  const datos = loginSchema.safeParse(req.body);
  if (!datos.success) {
    return res.status(400).json({ error: 'Correo o contraseña inválidos' });
  }

  try {
    const resultado = await login(datos.data.correo, datos.data.password);
    if (!resultado) {
      return res.status(401).json({ error: 'Credenciales incorrectas' });
    }
    return res.json(resultado);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}

export async function perfilController(req: Request, res: Response) {
  try {
    const result = await pool.query(
      `SELECT u.id_usuario, u.nombre, u.apellido, u.correo, r.nombre AS rol
       FROM usuarios u
       JOIN roles r ON r.id_rol = u.id_rol_sistema
       WHERE u.id_usuario = $1`,
      [req.usuario!.id]
    );
    if (!result.rows[0]) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    return res.json(result.rows[0]);
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: 'Error interno del servidor' });
  }
}