import { Router } from 'express';
import { loginController, perfilController } from '../controllers/auth.controller';
import { verificarToken } from '../middlewares/auth.middleware';

const router = Router();

router.post('/login', loginController);
router.get('/perfil', verificarToken, perfilController);

export default router;