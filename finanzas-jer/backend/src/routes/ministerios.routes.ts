import { Router } from 'express';
import { verificarToken, requiereRol } from '../middlewares/auth.middleware';
import {
  listarController,
  crearController,
  editarController,
} from '../controllers/ministerios.controller';

const router = Router();

router.use(verificarToken);

router.get('/', requiereRol('admin', 'pastor'), listarController);
router.post('/', requiereRol('admin'), crearController);
router.put('/:id', requiereRol('admin'), editarController);

export default router;