import { Router } from 'express';
import { verificarToken, requiereRol } from '../middlewares/auth.middleware';
import {
  listarController,
  crearController,
  editarController,
  membresiaController,
  passwordController,
  revocarController,
} from '../controllers/usuarios.controller';

const router = Router();

router.use(verificarToken, requiereRol('admin'));

router.get('/', listarController);
router.post('/', crearController);
router.put('/:id', editarController);
router.put('/:id/password', passwordController);
router.post('/:id/membresias', membresiaController);
router.delete('/:id/membresias/:idMinisterio', revocarController);

export default router;