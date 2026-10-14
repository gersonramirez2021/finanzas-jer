import bcrypt from 'bcrypt';
import { pool } from './config/db';

async function main() {
  const correo = 'admin@jer.com';
  const passwordPlano = 'Admin12345';

  const hash = await bcrypt.hash(passwordPlano, 10);

  const rol = await pool.query("SELECT id_rol FROM roles WHERE nombre = 'admin'");
  const idRol = rol.rows[0].id_rol;

  await pool.query(
    `INSERT INTO usuarios (nombre, apellido, correo, password_hash, id_rol_sistema)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (correo) DO NOTHING`,
    ['Administrador', 'Sistema', correo, hash, idRol]
  );

  console.log('Admin creado:', correo);
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});