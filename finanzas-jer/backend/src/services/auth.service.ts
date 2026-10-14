import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { pool } from '../config/db';

export async function login(correo: string, password: string) {
  const result = await pool.query(
    `SELECT u.id_usuario, u.nombre, u.apellido, u.correo, u.password_hash,
            u.activo, r.nombre AS rol
     FROM usuarios u
     JOIN roles r ON r.id_rol = u.id_rol_sistema
     WHERE u.correo = $1`,
    [correo]
  );

  const usuario = result.rows[0];
  if (!usuario || !usuario.activo) return null;

  const valida = await bcrypt.compare(password, usuario.password_hash);
  if (!valida) return null;

  const token = jwt.sign(
    { id: usuario.id_usuario, rol: usuario.rol },
    process.env.JWT_SECRET as string,
    { expiresIn: (process.env.JWT_EXPIRES_IN || '8h') as jwt.SignOptions['expiresIn'] }
  );

  return {
    token,
    usuario: {
      id: usuario.id_usuario,
      nombre: usuario.nombre,
      apellido: usuario.apellido,
      correo: usuario.correo,
      rol: usuario.rol,
    },
  };
}