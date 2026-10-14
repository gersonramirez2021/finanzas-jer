import { Router } from 'express';
import { pool } from '../config/db';
import { verificarToken } from '../middlewares/auth.middleware';

const router = Router();

router.use(verificarToken);

// Ministerios que el usuario puede ver, con su cargo en cada uno
router.get('/', async (req, res) => {
  const { id, rol } = req.usuario!;
  try {
    let r;
    if (rol === 'pastor' || rol === 'admin') {
      r = await pool.query(
        `SELECT id_ministerio, nombre, es_privado, $1::text AS cargo
         FROM ministerios
         WHERE activo = TRUE AND ($1 = 'pastor' OR es_privado = FALSE)
         ORDER BY nombre`,
        [rol]
      );
    } else {
      r = await pool.query(
        `SELECT mi.id_ministerio, mi.nombre, mi.es_privado, ro.nombre AS cargo
         FROM membresias me
         JOIN ministerios mi ON mi.id_ministerio = me.id_ministerio
         JOIN roles ro ON ro.id_rol = me.id_rol
         WHERE me.id_usuario = $1 AND me.activo = TRUE AND mi.activo = TRUE
         ORDER BY mi.nombre`,
        [id]
      );
    }
    res.json(r.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;
