import { Router } from 'express';
import { pool } from '../config/db';
import { verificarToken } from '../middlewares/auth.middleware';

const router = Router();

router.use(verificarToken);

router.get('/', async (req, res) => {
  const tipo = typeof req.query.tipo === 'string' ? req.query.tipo : null;
  const idMinisterio = req.query.idMinisterio ? Number(req.query.idMinisterio) : null;

  try {
    const r = await pool.query(
      `SELECT id_categoria, nombre, tipo
       FROM categorias
       WHERE activa = TRUE
         AND ($1::text IS NULL OR tipo = $1)
         AND (id_ministerio IS NULL OR id_ministerio = $2)
       ORDER BY nombre`,
      [tipo, idMinisterio]
    );
    res.json(r.rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router;