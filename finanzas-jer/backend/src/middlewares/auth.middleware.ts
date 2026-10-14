import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface UsuarioToken {
  id: number;
  rol: string;
}

declare global {
  namespace Express {
    interface Request {
      usuario?: UsuarioToken;
    }
  }
}

export function verificarToken(req: Request, res: Response, next: NextFunction) {
  const cabecera = req.headers.authorization;

  if (!cabecera || !cabecera.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token requerido' });
  }

  const token = cabecera.slice(7);

  try {
    const datos = jwt.verify(token, process.env.JWT_SECRET as string) as UsuarioToken;
    req.usuario = { id: datos.id, rol: datos.rol };
    next();
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado' });
  }
}

export function requiereRol(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.usuario || !roles.includes(req.usuario.rol)) {
      return res.status(403).json({ error: 'No tienes permiso para esta acción' });
    }
    next();
  };
}