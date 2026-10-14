import { Router } from 'express';
import { verificarToken } from '../middlewares/auth.middleware';
import {
  registrarController,
  listarController,
  editarController,
  decidirController,
} from '../controllers/movimientos.controller';

const router = Router();

router.use(verificarToken);

router.get('/', listarController);
router.post('/', registrarController);
router.put('/:id', editarController);
router.post('/:id/decision', decidirController);

export default router;